import 'dart:async';

import 'package:dio/dio.dart';
import 'package:client/auth/api_client.dart';
import 'package:client/model/login_results_model.dart';

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

  // Use the shared Dio client so cookies (refresh token) are persisted by CookieManager.
  Dio get _dio => ApiClient.I.dio;

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
  // Public API
  // ---------------------------------------------------------------------------

  /// Submits the login credentials to the backend and returns a [LoginResultModel].
  ///
  /// Uses the shared Dio client so that cookies (e.g., refresh token) set by the
  /// backend are captured by CookieManager and persisted for subsequent refresh.
  /// Sends a `POST` to `/api/auth/login` with JSON body.
  Future<LoginResultModel> submitFormDataToServer() async {
    // Build URL relative to the configured base; rely on ApiClient normalization.
    final path = normalizeApiPath(ApiClient.I.dio, '/api/auth/login');
    try {
      final res = await _dio
          .post(
            path,
            data: {
              'email': email.trim(),
              'password': password.trim(),
            },
            options: Options(
              headers: {'Content-Type': 'application/json'},
            ),
          )
          .timeout(const Duration(seconds: 15));

      final status = res.statusCode ?? 0;
      final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};

      if (status == 200) {
        final token = data['token'] as String? ?? data['accessToken'] as String?;
        if (token == null) {
          return LoginResultModel.global('Malformed success response');
        }
        return LoginResultModel.success(token);
      }

      switch (status) {
        case 400:
        case 422:
          return LoginResultModel.fieldErrors(
            emailError: data['email'] as String?,
            passwordError: data['password'] as String?,
            message: data['message'] as String?,
          );
        case 401:
          return LoginResultModel.global(
            data['message'] as String? ?? 'Invalid email or password',
          );
        case 404:
          return LoginResultModel.fieldErrors(
            emailError: data['email'] as String? ?? 'User not found',
          );
        case 429:
          return LoginResultModel.global(
            data['message'] as String? ?? 'Too many attempts. Try later.',
          );
        default:
          return LoginResultModel.global(
            (data['message'] as String?) ?? 'Server error ($status). Please try again.',
          );
      }
    } on TimeoutException {
      return LoginResultModel.global('Request timed out. Please try again.');
    } on DioException catch (e) {
      final s = e.response?.statusCode ?? 0;
      final m = e.response?.data is Map<String, dynamic> ? (e.response!.data['message'] as String?) : null;
      if (s == 401) return LoginResultModel.global(m ?? 'Invalid email or password');
      if (s == 404) return LoginResultModel.fieldErrors(emailError: m ?? 'User not found');
      if (s == 429) return LoginResultModel.global(m ?? 'Too many attempts. Try later.');
      if (s == 400 || s == 422) {
        final data = e.response?.data as Map<String, dynamic>?;
        return LoginResultModel.fieldErrors(
          emailError: data?['email'] as String?,
          passwordError: data?['password'] as String?,
          message: data?['message'] as String?,
        );
      }
      return LoginResultModel.global(m ?? 'Unexpected error. Please try again.');
    } catch (_) {
      return LoginResultModel.global('Unexpected error. Please try again.');
    }
  }
}
