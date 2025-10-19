library;

import 'dart:async';

import 'package:client/auth/auth_store.dart';
import 'package:client/auth/role_store.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class _Endpoints {
  static const String refresh = '/api/auth/refresh';
  static const String logout  = '/api/auth/logout';
}

// Returns a path that won't double-include `/api` if baseUrl already ends with `/api`
String _normalizeApiPath(Dio dio, String path) {
  final base = dio.options.baseUrl;
  final hasApiInBase = base.endsWith('/api') || base.contains('/api/');
  if (hasApiInBase && path.startsWith('/api/')) {
    return path.replaceFirst('/api/', '/');
  }
  return path;
}

// Public wrapper so other libraries can safely normalize API paths without
// accessing a library-private symbol. This keeps existing internal calls
// unchanged while exposing the utility for API client files.
String normalizeApiPath(Dio dio, String path) => _normalizeApiPath(dio, path);

class ApiClient {
  ApiClient._(this.dio, this.cookieJar);

  final Dio dio;
  final PersistCookieJar cookieJar;

  static ApiClient? _instance;

  static Future<ApiClient> init(String baseUrl) async {
    if (_instance != null) return _instance!;

    final appDocDir = await getApplicationDocumentsDirectory();
    final jar = PersistCookieJar(storage: FileStorage('${appDocDir.path}/cookies'));

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    // 👇 add them here
    dio.interceptors.add(CookieManager(jar));
    dio.interceptors.add(_AuthInterceptor(dio));

    _instance = ApiClient._(dio, jar);
    return _instance!;
  }

  static ApiClient get I {
    final i = _instance;
    if (i == null) {
      throw StateError('ApiClient not initialized. Call ApiClient.init(baseUrl) first.');
    }
    return i;
  }

  static CancelToken _sessionCancelToken = CancelToken();
  static CancelToken get sessionCancelToken => _sessionCancelToken;

  static void _resetSessionCancelToken() {
    if (!_sessionCancelToken.isCancelled) {
      _sessionCancelToken.cancel('Logged out');
    }
    _sessionCancelToken = CancelToken();
  }

  /// Print current auth diagnostics: baseUrl and cookies for that origin.
  static Future<void> debugPrintAuthState() async {
    final i = _instance;
    if (i == null) {
      // ignore: avoid_print
      print('[ApiClient] Not initialized.');
      return;
    }
    final base = i.dio.options.baseUrl;
    try {
      final uri = Uri.parse(base);
      // Ensure we always query cookies for the origin (no path)
      final origin = Uri(scheme: uri.scheme, host: uri.host, port: uri.port, path: '/');
      final cookies = await i.cookieJar.loadForRequest(origin);
      // ignore: avoid_print
      print('[ApiClient] baseUrl=$base origin=$origin cookies=$cookies');
    } catch (e) {
      // ignore: avoid_print
      print('[ApiClient] Failed to print auth state: $e');
    }
  }

  static Future<void> logout({bool callServer = true}) async {
    if (callServer && _instance != null) {
      try {
        await _instance!.dio.post(
          _normalizeApiPath(_instance!.dio, _Endpoints.logout),
          options: Options(headers: {'Authorization': null}),
        );
      } catch (_) {}
    }

    // Clear all local auth state to avoid cross-account leakage:
    // - Access token in secure storage
    // - In-memory cached role
    // - Cookies (including refresh tokens)
    await AuthStore.clear();
    try {
      RoleStore.clear();
    } catch (_) {}

    final i = _instance;
    if (i != null) {
      await i.cookieJar.deleteAll();
    }

    _resetSessionCancelToken();
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;

  String get _refreshPath => _normalizeApiPath(_dio, _Endpoints.refresh);

  bool _isRefreshing = false;
  final List<_QueuedRequest> _queue = [];

  static const _kSkipRetryKey = 'x-skip-refresh'; // guard to avoid recursion

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final token = await AuthStore.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode ?? 0;
    final path = err.requestOptions.path;
    final isRefreshCall = path.endsWith(_refreshPath);

    // Not a 401, or it's the refresh call itself → pass through
    if (status != 401 || isRefreshCall || err.requestOptions.extra[_kSkipRetryKey] == true) {
      handler.next(err);
      return;
    }

    // Queue this failed request
    final completer = Completer<Response<dynamic>>();
    _queue.add(_QueuedRequest(err.requestOptions, completer));

    if (!_isRefreshing) {
      _isRefreshing = true;
      try {
        // DEBUG: print cookie state for the base origin to ensure refresh cookie will be sent
        try {
          final base = _dio.options.baseUrl;
          final uri = Uri.parse(base);
          final origin = Uri(scheme: uri.scheme, host: uri.host, port: uri.port, path: '/');
          // We need access to the jar via ApiClient singleton
          final jar = ApiClient.I.cookieJar;
          final cookies = await jar.loadForRequest(origin);
          // ignore: avoid_print
          print('[AuthInterceptor] Preparing refresh: base=$base origin=$origin cookies=$cookies');
        } catch (_) {}

        // IMPORTANT: do not send Authorization header on refresh
        final refreshResp = await _dio.post(
          _refreshPath,
          options: Options(
            headers: {'Authorization': null},
            // prevent this request from being intercepted recursively
            extra: { _kSkipRetryKey: true },
          ),
        );

        final data = refreshResp.data;
        final newAccessToken =
            data?['accessToken'] ?? data?['token'] ?? data?['access_token'];

        if (newAccessToken is String && newAccessToken.isNotEmpty) {
          // Persist new access token
          await AuthStore.saveToken(newAccessToken);

          // Replay queued requests with the fresh token
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
          // No token in refresh response → treat as unauthenticated
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
      } catch (e) {
        // Refresh failed → fail all queued requests and logout
        for (final q in _queue) {
          if (!q.completer.isCompleted) q.completer.completeError(e);
        }
        await ApiClient.logout();
      } finally {
        _queue.clear();
        _isRefreshing = false;
      }
    }

    // Resolve this error with the replayed response when it completes
    try {
      final resp = await completer.future;
      handler.resolve(resp);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<RequestOptions> _rebuildWithToken(RequestOptions old, String token) async {
    final headers = Map<String, dynamic>.from(old.headers);
    headers['Authorization'] = 'Bearer $token';
    final extra = Map<String, dynamic>.from(old.extra);
    extra.remove(_kSkipRetryKey); // normal requests can be retried again later
    return old.copyWith(
      headers: headers,
      extra: extra,
    );
  }
}

class _QueuedRequest {
  _QueuedRequest(this.options, this.completer);
  final RequestOptions options;
  final Completer<Response<dynamic>> completer;
}