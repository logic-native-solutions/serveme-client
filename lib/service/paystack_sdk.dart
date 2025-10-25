import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// PaystackSdkService (Stub for build compatibility)
/// -------------------------------------------------
/// This stub avoids importing the flutter_paystack plugin, which currently
/// fails to compile against the project's Flutter SDK due to deprecated
/// TextTheme getters removed in Material 3 (e.g., headline1/headline6).
///
/// Behavior
/// - initOnce caches the provided public key and becomes a no-op.
/// - checkoutWithAccessCode returns false so callers can fall back to the
///   browser-based zero-amount card link flow.
///
/// Once a Material 3–compatible Paystack SDK (or a patched fork) is available,
/// replace this file with the real implementation and re-add the dependency in
/// pubspec.yaml.
class PaystackSdkService {
  PaystackSdkService._();
  static final PaystackSdkService I = PaystackSdkService._();

  bool _initialized = false;
  String? _publicKey;
  // Note: We intentionally avoid logging from this stub to keep console clean.

  bool get isInitialized => _initialized;
  String? get publicKey => _publicKey;

  Future<void> initOnce(String publicKey) async {
    // Idempotent initialization: cache the key and mark initialized once.
    if (_initialized && _publicKey == publicKey) return;
    _publicKey = publicKey;
    _initialized = true;
    // No debug prints here: the absence of the real SDK is expected in some builds.
  }

  Future<bool> checkoutWithAccessCode({
    required BuildContext context,
    required String accessCode,
    required String email,
  }) async {
    // Always return false so the UI uses the browser-based fallback.
    // We avoid debug prints to keep logs quiet in production and debug.
    return false;
  }
}
