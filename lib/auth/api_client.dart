/// ---------------------------------------------------------------------------
/// ApiClient
/// Centralized HTTP client built on Dio with:
///   • Persisted cookie jar for refresh-token cookies
///   • Bearer access-token injection from AuthStore
///   • Automatic 401 handling with queued request replay after /refresh
///   • Session-wide CancelToken for mass-cancel on logout
///
/// Usage
/// -----
///   await ApiClient.init(baseUrl);
///   final dio = ApiClient.I.dio;
///
///   // Attach the shared session cancel token to requests if you want them
///   // cancelled automatically on logout:
///   dio.get('/me', cancelToken: ApiClient.sessionCancelToken);
///
///   // To logout (best-effort server + local cleanup):
///   await ApiClient.logout();
/// ---------------------------------------------------------------------------
library;

import 'dart:async';

import 'package:client/auth/auth_store.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight endpoint constants (kept here to avoid magic strings).
class _Endpoints {
  static const String refresh = '/refresh';
  static const String logout = '/logout';
}

/// A singleton wrapper around a configured [Dio] instance.
class ApiClient {
  ApiClient._(this.dio, this.cookieJar);

  /// Underlying Dio instance used by the entire app.
  final Dio dio;

  /// Persistent cookie storage (used by server refresh-cookie strategy).
  final PersistCookieJar cookieJar;

  // -------------------------------------------------------------------------
  // Singleton lifecycle
  // -------------------------------------------------------------------------
  static ApiClient? _instance;

  /// Initializes the singleton client. Safe to call multiple times; the first
  /// call wins and subsequent calls return the same instance.
  static Future<ApiClient> init(String baseUrl) async {
    if (_instance != null) return _instance!;

    // Persist cookies under app document directory (isolated per app install).
    final appDocDir = await getApplicationDocumentsDirectory();
    final jar = PersistCookieJar(
      storage: FileStorage('${appDocDir.path}/cookies'),
    );

    // Configure Dio base options once for the whole app.
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    // Register interceptors (order matters: cookies first, then auth).
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(_AuthInterceptor(dio));

    _instance = ApiClient._(dio, jar);
    return _instance!;
  }

  /// Accessor for the initialized singleton instance.
  static ApiClient get I {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'ApiClient not initialized. Call ApiClient.init(baseUrl) first.',
      );
    }
    return i;
  }

  // -------------------------------------------------------------------------
  // Session management
  // -------------------------------------------------------------------------

  /// A shared [CancelToken] used to cancel all in-flight requests on logout.
  static CancelToken _sessionCancelToken = CancelToken();

  /// Provide the current session token to attach to requests.
  static CancelToken get sessionCancelToken => _sessionCancelToken;

  /// Resets the shared session token, cancelling any current requests.
  static void _resetSessionCancelToken() {
    if (!_sessionCancelToken.isCancelled) {
      _sessionCancelToken.cancel('Logged out');
    }
    _sessionCancelToken = CancelToken();
  }

  /// Logs out the user: attempts server logout, clears local auth state,
  /// wipes cookies, and cancels all in-flight requests.
  static Future<void> logout({bool callServer = true}) async {
    // 1) Best-effort server side logout (clear refresh-cookie / revoke token).
    if (callServer && _instance != null) {
      try {
        await _instance!.dio.post(
          _Endpoints.logout,
          options: Options(
            // Do NOT send Authorization header – rely on httpOnly refresh cookie.
            headers: {'Authorization': null},
          ),
        );
      } catch (_) {
        // Network/server failure shouldn’t block local cleanup.
      }
    }

    // 2) Clear local app auth state.
    await AuthStore.clear();

    // 3) Wipe cookies so future refresh cannot succeed silently.
    final i = _instance;
    if (i != null) {
      await i.cookieJar.deleteAll();
    }

    // 4) Cancel any in-flight requests and rotate the session cancel token.
    _resetSessionCancelToken();
  }
}

// =============================================================================
// Interceptors
// =============================================================================

/// Handles access-token injection and 401-refresh replay logic.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  bool _isRefreshing = false;
  final List<_QueuedRequest> _queue = [];

  // ---------------------------------------------------------------------------
  // Outgoing request: attach Bearer token when available.
  // ---------------------------------------------------------------------------
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await AuthStore.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Swallow read failures; request proceeds without Authorization header.
    }
    handler.next(options);
  }

  // ---------------------------------------------------------------------------
  // Error handling: intercept 401s, call /refresh once, replay queued requests.
  // ---------------------------------------------------------------------------
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Only handle 401s. Avoid loops when the failing call is /refresh itself.
    if (status != 401 || path.endsWith(_Endpoints.refresh)) {
      handler.next(err);
      return;
    }

    // Queue the failed request so we can retry it after refresh.
    final completer = Completer<Response<dynamic>>();
    _queue.add(_QueuedRequest(err.requestOptions, completer));

    // If a refresh isn’t in-flight, start one.
    if (!_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshResp = await _dio.post(
          _Endpoints.refresh,
          options: Options(headers: {'Authorization': null}),
        );

        final data = refreshResp.data;
        final newAccessToken =
            data?['accessToken'] ?? data?['token'] ?? data?['access_token'];

        if (newAccessToken is String && newAccessToken.isNotEmpty) {
          await AuthStore.saveToken(newAccessToken);

          // Replay everything we queued while refreshing.
          for (final q in _queue) {
            try {
              final req = await _rebuildWithToken(q.options, newAccessToken);
              final r = await _dio.fetch(req);
              if (!q.completer.isCompleted) q.completer.complete(r);
            } catch (e) {
              if (!q.completer.isCompleted) q.completer.completeError(e);
            }
          }
        } else {
          // No token returned → treat as refresh failure, propagate 401s and logout.
          for (final q in _queue) {
            if (!q.completer.isCompleted) {
              q.completer.completeError(
                DioException(
                  requestOptions: q.options,
                  response: Response(requestOptions: q.options, statusCode: 401),
                  type: DioExceptionType.badResponse,
                ),
              );
            }
          }
          await ApiClient.logout();
        }
      } catch (e, st) {
        debugPrint('Refresh failed: $e\n$st');
        for (final q in _queue) {
          if (!q.completer.isCompleted) q.completer.completeError(e);
        }
        await ApiClient.logout();
      } finally {
        _queue.clear();
        _isRefreshing = false;
      }
    }

    // For the current request, wait for the replay result or propagate original error.
    try {
      final resp = await completer.future;
      handler.resolve(resp);
    } catch (_) {
      handler.next(err); // Bubble the original 401 if refresh/replay failed.
    }
  }

  /// Rebuilds a request with the new Authorization header.
  Future<RequestOptions> _rebuildWithToken(
    RequestOptions old,
    String token,
  ) async {
    return old.copyWith(
      method: old.method,
      headers: {
        ...old.headers,
        'Authorization': 'Bearer $token',
      },
      path: old.path,
      data: old.data,
      queryParameters: old.queryParameters,
      responseType: old.responseType,
      contentType: old.contentType,
      validateStatus: old.validateStatus,
      sendTimeout: old.sendTimeout,
      receiveTimeout: old.receiveTimeout,
    );
  }
}

/// A simple container for a request we plan to retry once refresh completes.
class _QueuedRequest {
  _QueuedRequest(this.options, this.completer);
  final RequestOptions options;
  final Completer<Response<dynamic>> completer;
}