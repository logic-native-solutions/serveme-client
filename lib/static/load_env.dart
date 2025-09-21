import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ---------------------------------------------------------------------------
/// Env
///
/// A tiny utility around `flutter_dotenv` that:
///  • Loads the .env file once (idempotent)
///  • Provides safe accessors with clear errors when a key is missing/empty
///  • Exposes typed getters for commonly used keys
///  • Helps you build API URIs consistently
/// ---------------------------------------------------------------------------
class Env {
  static bool _loaded = false;

  /// Loads environment variables from [fileName]. Safe to call multiple times.
  static Future<void> load({String fileName = '.env'}) async {
    if (_loaded) return;
    await dotenv.load(fileName: fileName);
    _loaded = true;
  }

  /// Returns the value for [key] or throws a clear error if missing/empty.
  static String require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) {
      throw StateError(
        'Missing or empty environment variable: "$key".\n'
        '• Ensure the key exists in your .env file.\n'
        '• Make sure the .env file is bundled/loaded before use.',
      );
    }
    return value;
  }

  /// Convenience: indicates whether the app is running in release mode.
  static bool get isRelease => kReleaseMode;

  // -------------------------------------------------------------------------
  // Typed accessors (add more as needed)
  // -------------------------------------------------------------------------

  /// Base HTTPS server URL, e.g. `https://api.example.com`.
  static String get httpsServer => require('HTTPS_SERVER');

  /// Builds a full [Uri] by resolving [path] (and optional [query]) against
  /// [httpsServer]. Example: `Env.apiUri('/api/auth/register')`.
  static Uri apiUri(String path, {Map<String, dynamic>? query}) {
    final base = Uri.parse(httpsServer);
    final resolved = base.resolve(path);
    return resolved.replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }
}

// ---------------------------------------------------------------------------
// Backwards-compatible exports (optional). Prefer using Env.httpsServer.
// ---------------------------------------------------------------------------
@Deprecated('Use Env.httpsServer instead')
String get serverBaseUrl => Env.httpsServer;

/// Call this early in your app startup (e.g., main())
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Env.load();
///   runApp(const MyApp());
/// }
/// ```
Future<void> loadEnv() => Env.load();