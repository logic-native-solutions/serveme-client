import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:client/model/login_results.dart';

/// ---------------------------------------------------------------------------
/// LoginUserService
/// Handles user login by submitting credentials to the backend and mapping
/// responses into [LoginResultModel] instances.
///
/// Responsibilities
/// ----------------
/// • Encode email & password as JSON.
/// • POST to the server's `/api/auth/login`.
/// • Handle success, validation errors, and network issues gracefully.
/// • Return a typed [LoginResultModel] for each outcome.
/// ---------------------------------------------------------------------------
class LoginUserService {
  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// User's email address.
  final String email;

  /// User's plaintext password.
  final String password;

  /// Base URL (with port) of the backend server.
  final String serverPort;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a [LoginUserService] with the given [email], [password], and [serverPort].
  const LoginUserService({
    required this.email,
    required this.password,
    required this.serverPort,
  });

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Attempts to decode [body] as JSON, returning a map or `null` if invalid.
  Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Submits the login credentials to the backend and returns a [LoginResultModel].
  ///
  /// Sends a `POST` request to `'$serverPort/api/auth/login'` with
  /// `{'email': email, 'password': password}` as JSON.
  /// Handles various HTTP status codes and common errors:
  /// - `200`: success, returns a token.
  /// - `400/422`: field validation errors.
  /// - `401`: unauthorized (wrong credentials).
  /// - `404`: user not found.
  /// - `429`: too many attempts.
  /// - Others: generic server error.
  /// Also catches [TimeoutException], [SocketException], and any unexpected error.
  Future<LoginResultModel> submitFormDataToServer() async {
    final url = Uri.parse('$serverPort/api/auth/login');
    final body = jsonEncode({'email': email.trim(), 'password': password.trim()});

    try {
      final res = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic>? resBody = _tryParseJson(res.body);

      if (res.statusCode == 200) {
        final token = resBody?['token'] as String?;
        if (token == null) {
          return LoginResultModel.global('Malformed success response');
        }
        return LoginResultModel.success(token);
      }

      // Map common error patterns
      switch (res.statusCode) {
        case 400:
        case 422:
          return LoginResultModel.fieldErrors(
            emailError: resBody?['email'] as String?,
            passwordError: resBody?['password'] as String?,
            message: resBody?['message'] as String?,
          );
        case 401:
          return LoginResultModel.global(
            resBody?['message'] as String? ?? 'Invalid email or password',
          );
        case 404:
          return LoginResultModel.fieldErrors(
            emailError: resBody?['email'] as String? ?? 'User not found',
          );
        case 429:
          return LoginResultModel.global(
            resBody?['message'] as String? ?? 'Too many attempts. Try later.',
          );
        default:
          return LoginResultModel.global(
            (resBody?['message'] as String?) ??
                'Server error (${res.statusCode}). Please try again.',
          );
      }
    } on TimeoutException {
      return LoginResultModel.global('Request timed out. Please try again.');
    } on SocketException {
      return LoginResultModel.global('Network error. Check your connection.');
    } catch (_) {
      return LoginResultModel.global('Unexpected error. Please try again.');
    }
  }
}
