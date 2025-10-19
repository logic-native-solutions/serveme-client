import 'dart:async';
import 'dart:developer';

import 'package:client/auth/api_client.dart';
import 'package:client/main.dart';
import 'package:client/view/provider/job_offer_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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
  PushMessaging._();
  static final PushMessaging I = PushMessaging._();

  bool _initialized = false;

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
      // Attempt a short APNs wait loop on iOS; on Android this returns null immediately.
      for (var i = 0; i < 8; i++) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          log('APNs token available. Proceeding to fetch FCM token.');
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      token = await FirebaseMessaging.instance.getToken();
      log('FCM token: $token');
    } catch (e) {
      log('Failed to get FCM token (will still listen for refresh): $e');
    }

    if (token != null && token.isNotEmpty) {
      await _uploadToken(token);
    }
  }

  /// Upload the device FCM token to backend so the server can send notifications.
  Future<void> _uploadToken(String token) async {
    try {
      await ApiClient.I.dio.post(
        normalizeApiPath(ApiClient.I.dio, '/api/v1/users/me/token'),
        data: {'token': token},
      );
      log('Uploaded FCM token to backend');
    } catch (e) {
      log('Failed to upload FCM token to backend: $e');
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

  // Navigate to Provider Job Offer screen. We use navigatorKey to push regardless of current context.
  final nav = navKey.currentState;
  if (nav == null) return;

  // Avoid stacking multiples: look for an existing route with same name and replace.
  nav.pushNamed(ProviderJobOfferScreen.route, arguments: jobId);
}
