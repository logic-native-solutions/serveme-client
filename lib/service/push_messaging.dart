import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:client/auth/api_client.dart';
import 'package:client/auth/auth_store.dart';
import 'package:client/view/provider/job_offer_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// PushMessaging
/// Centralized Firebase Cloud Messaging (FCM) integration for ServeMe.
///
/// Responsibilities:
///  • Initialize Firebase (Dart side) and request notification permissions on iOS.
///  • Obtain and refresh the FCM token and upload it to backend.
///  • Listen for FCM data messages in foreground/background/terminated states.
///  • When a provider receives `type=job_offer`, deep-link to the Job Offer screen.
///
/// Notes:
///  • We intentionally keep this minimal and theme-agnostic. UI is handled by the destination pages.
///  • Data messages are expected with keys: type=job_offer, jobId=<id>, serviceType=<type>.
class PushMessaging {
  // This class now defers FCM token upload until the app is authenticated.
  // Rationale: Uploading while unauthenticated causes 401s because the backend
  // requires a logged-in session (cookies/Authorization). We cache the token
  // and retry after login, with bounded backoff.
  PushMessaging._();
  static final PushMessaging I = PushMessaging._();

  bool _initialized = false;

  // Track last successfully uploaded token to avoid redundant uploads.
  String? _lastUploadedToken;
  // Prevent concurrent uploads and coordinate retries.
  bool _uploadInFlight = false;
  Timer? _retryTimer;

  /// Must be called once from app startup (e.g., in AppState.initState()).
  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    if (_initialized) return;

    // 1) Ensure Firebase is initialized. If already initialized, skip.
    try {
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      // Some environments may throw if already initialized; ignore.
      log('Firebase initialize check: $e');
    }

    // 2) Request permissions (Android 13+ runtime notifications; iOS shows system prompt).
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    log('FCM permission status: ${settings.authorizationStatus}');

    // Ensure auto-init is enabled so FCM starts as early as possible on iOS.
    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (e) {
      log('Failed to enable FCM auto-init: $e');
    }

    // Ensure iOS foreground notifications are displayed when the app is active.
    // Without this, iOS will suppress notification banners/sounds in foreground.
    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      log('Failed to set iOS foreground presentation options: $e');
    }

    // 3) Token fetch + refresh with backend upload.
    await _ensureFcmTokenUploadedWithApnsWait();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      log('FCM token refreshed: $token');
      await _uploadToken(token);
    });

    // 4) Foreground messages.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessage(message, navKey, openedFromTray: false);
    });

    // 5) Notification taps when app in background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message, navKey, openedFromTray: true);
    });

    // 6) Handle cold start open.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleMessage(initial, navKey, openedFromTray: true);
    }

    _initialized = true;
  }

  /// Try to obtain an APNs token on iOS before calling getToken, since FCM relies on APNs for iOS.
  /// We wait up to ~8 seconds, then proceed anyway to avoid blocking startup.
  Future<void> _ensureFcmTokenUploadedWithApnsWait() async {
    String? token;
    try {
      // iOS: Wait for APNs token to be set before calling getToken().
      // Some devices may take several seconds after permission to provide APNs.
      // We'll wait up to ~60 seconds with incremental backoff.
      const totalAttempts = 12; // 12 attempts
      var delay = const Duration(seconds: 1);
      for (var attempt = 1; attempt <= totalAttempts; attempt++) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          log('APNs token available on attempt $attempt.');
          break; // proceed to getToken
        }
        // On Android, getAPNSToken returns null; we shouldn't block too long.
        // Break early on Android by trying getToken quickly after a couple of short waits.
        if (!Platform.isIOS && attempt == 2) {
          log('APNs token not applicable or not ready yet; proceeding with getToken attempt soon.');
          break;
        }
        await Future<void>.delayed(delay);
        // Exponential backoff up to 8 seconds between checks.
        if (delay.inSeconds < 8) {
          delay = Duration(seconds: delay.inSeconds * 2);
        }
      }

      // Try to fetch the FCM token with retries, because it may still throw if APNs not set yet.
      const tokenAttempts = 5;
      delay = const Duration(milliseconds: 400);
      Object? lastErr;
      for (var i = 1; i <= tokenAttempts; i++) {
        try {
          token = await FirebaseMessaging.instance.getToken();
          if (token != null && token!.isNotEmpty) {
            log('FCM token acquired on attempt $i');
            break;
          }
        } catch (e) {
          lastErr = e;
          final msg = e.toString();
          // If it's the APNS not set error, keep retrying with backoff.
          if (msg.contains('apns-token-not-set') || msg.contains('APNS')) {
            log('getToken failed (APNs not ready yet). Attempt $i/$tokenAttempts');
          } else {
            log('getToken failed with non-APNs error on attempt $i: $e');
          }
        }
        await Future<void>.delayed(delay);
        // Backoff to a max of 5 seconds.
        if (delay.inMilliseconds < 5000) {
          delay = Duration(milliseconds: (delay.inMilliseconds * 2).clamp(400, 5000));
        }
      }

      if (token == null || token!.isEmpty) {
        if (lastErr != null) {
          log('Failed to get FCM token after retries: $lastErr');
        } else {
          log('Failed to get FCM token after retries: token is empty');
        }
      } else {
        log('FCM token: $token');
      }
    } catch (e) {
      log('Failed to get FCM token (will still listen for refresh): $e');
    }

    if (token != null && token!.isNotEmpty) {
      await _uploadToken(token!);
    }
  }

  /// Upload the device FCM token to backend so the server can send notifications.
  /// This method is auth-aware: it defers upload until a session exists and
  /// retries with bounded backoff if the server responds with 401.
  Future<void> _uploadToken(String token) async {
    // Avoid redundant uploads if we already uploaded this token successfully.
    if (_lastUploadedToken == token) {
      return;
    }

    // Prevent concurrent uploads; remember the latest token we want to upload.
    if (_uploadInFlight) {
      _pendingToken = token;
      return;
    }

    // If not authenticated yet, schedule a retry and exit early.
    if (!AuthStore.hasToken) {
      log('[FCM] Not authenticated yet; deferring token upload.');
      _scheduleRetry(token);
      return;
    }

    _uploadInFlight = true;
    try {
      final resp = await ApiClient.I.dio.post(
        normalizeApiPath(ApiClient.I.dio, '/api/v1/users/me/token'),
        data: {'token': token},
        // Ensure this call participates in the refresh/retry flow if access token expired
        cancelToken: ApiClient.sessionCancelToken,
      );
      // Success
      _lastUploadedToken = token;
      _pendingToken = null;
      _retrySeconds = 2; // reset backoff after a success
      _retryTimer?.cancel();
      log('Uploaded FCM token to backend (${resp.statusCode}).');
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401) {
        // Likely not logged in or refresh cookie not available yet. Retry later.
        log('[FCM] Token upload got 401; will retry after auth.');
        _scheduleRetry(token);
      } else {
        log('Failed to upload FCM token to backend: $e');
      }
    } catch (e) {
      log('Failed to upload FCM token to backend: $e');
    } finally {
      _uploadInFlight = false;
    }
  }

  // ------------------------- Retry management ---------------------------------
  String? _pendingToken;
  int _retrySeconds = 2; // Exponential backoff starting at 2s up to 60s

  void _scheduleRetry(String token, {Duration? delay}) {
    _pendingToken = token;
    _retryTimer?.cancel();
    final d = delay ?? Duration(seconds: _retrySeconds);
    _retryTimer = Timer(d, () async {
      // If user is still not authenticated, reschedule without spamming network.
      if (!AuthStore.hasToken) {
        _scheduleRetry(token);
        return;
      }
      await _uploadToken(token);
    });

    if (delay == null) {
      // Increase backoff only when we auto-decide the delay
      _retrySeconds = (_retrySeconds * 2).clamp(2, 60);
    }
  }
}

/// Background message handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final apps = Firebase.apps;
    if (apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  // We cannot navigate while backgrounded; simply log and let tap-open flow handle deep-link later.
  log('BG FCM: ${message.data}');
}

void _handleMessage(RemoteMessage message, GlobalKey<NavigatorState> navKey, {required bool openedFromTray}) {
  final data = message.data;
  final type = (data['type'] ?? data['Type'] ?? '').toString();
  if (type != 'job_offer') return;

  final jobId = (data['jobId'] ?? data['jobID'] ?? data['id'] ?? '').toString();
  if (jobId.isEmpty) return;

  final nav = navKey.currentState;
  final ctx = navKey.currentContext;
  if (nav == null) return;

  // If the user tapped the notification (openedFromTray), deep-link immediately.
  if (openedFromTray) {
    nav.pushNamed(ProviderJobOfferScreen.route, arguments: jobId);
    return;
  }

  // Otherwise (app in foreground), show a non-intrusive snackbar with an action to open the offer.
  if (ctx != null) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('New job offer'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            final n = navKey.currentState;
            n?.pushNamed(ProviderJobOfferScreen.route, arguments: jobId);
          },
        ),
      ),
    );
  } else {
    // Fallback: if no context, navigate directly to ensure the offer is not missed.
    nav.pushNamed(ProviderJobOfferScreen.route, arguments: jobId);
  }
}
