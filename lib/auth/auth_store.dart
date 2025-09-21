import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ---------------------------------------------------------------------------
/// AuthStore
/// Lightweight wrapper around [FlutterSecureStorage] for persisting the user's
/// access token securely on iOS and Android.
///
/// Features
/// --------
/// • Stores the token under a single key.
/// • Uses encrypted shared preferences on Android.
/// • Uses keychain (first unlock) on iOS.
/// • Exposes convenience helpers for login checks.
/// ---------------------------------------------------------------------------
class AuthStore {
  // ---------------------------------------------------------------------------
  // Constants & storage
  // ---------------------------------------------------------------------------

  /// Key used to store the access token.
  static const String _key = 'auth_token';

  /// Underlying secure storage instance.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Cached token kept in memory after initialization.
  static String? _cachedToken;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Initialize the store at app startup to warm up the session cache.
  static Future<void> init() async {
    _cachedToken = await readToken();
  }

  /// True if a token is cached and non-empty.
  static bool get hasToken => _cachedToken?.isNotEmpty == true;

  /// Cached token value (may be null if not initialized or not logged in).
  static String? get token => _cachedToken;

  /// Persist a new [token] securely.
  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _key, value: token);
  }

  /// Retrieve the current token, or `null` if not set.
  static Future<String?> readToken() => _storage.read(key: _key);

  /// Remove any stored token from secure storage.
  static Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: _key);
  }

  /// Convenience helper: `true` if a token is stored and non-empty.
  static Future<bool> isLoggedIn() async =>
      (await readToken())?.isNotEmpty == true;
}