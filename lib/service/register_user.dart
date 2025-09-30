import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:client/model/register_results_model.dart';

/// ---------------------------------------------------------------------------
/// RegisterUserService
///
/// A small, focused HTTP client for the registration endpoint.
///
/// Responsibilities
///  • Build a clean request payload from raw form values
///  • POST JSON to `/api/auth/register`
///  • Normalize server responses into a single `RegisterResultModel` type
///  • Provide resilient error handling (timeouts, offline, malformed JSON)
/// ---------------------------------------------------------------------------
class RegisterUserService {
  // ---------------------------------------------------------------------------
  // Constants & Configuration
  // ---------------------------------------------------------------------------
  final String baseUrl;

  /// Error message strings that the API may return verbatim.
  static const String _emailError = 'Email has already been registered';
  static const String _phoneError = 'Phone number has already been registered';
  static const String _idNumberError = 'Id number has already been registered';

  static const Duration _timeout = Duration(seconds: 15);
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  RegisterUserService(this.baseUrl);

  // ---------------------------------------------------------------------------
  // Helpers: Parsing & Mapping
  // ---------------------------------------------------------------------------
  /// Safely attempts to parse a JSON string into a map. Returns `null` if the
  /// body is empty, not JSON, or not a JSON object.
  static Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Maps known duplicate messages (when server replies with raw text) to the
  /// appropriate field-error map consumed by the UI.
  static Map<String, String>? _mapDuplicateFromPlainBody(String body) {
    switch (body) {
      case _phoneError:
        return {'phoneNumber': _phoneError};
      case _idNumberError:
        return {'idNumber': _idNumberError};
      case _emailError:
        return {'email': _emailError};
      default:
        return null;
    }
  }

  /// Builds the JSON request body for the registration API from raw inputs.
  static String _buildRequestBody({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String gender,
    required String idNumber,
    required DateTime dateOfBirth,
    required String email,
    required String password,
    required String role,
  }) {
    final payload = <String, dynamic>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'gender': gender.trim(),
      'idNumber': idNumber.trim(),
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
      'role': role.trim()
    };
    return jsonEncode(payload);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------
  /// Submits the registration form to the server and normalizes the response
  /// into a [`RegisterResultModel`].
  ///
  /// Success contract (HTTP 202):
  ///   `{ "status": "PENDING" | "VERIFIED" | ... }`
  ///
  /// Error contracts handled:
  ///   • HTTP 400/422: field validation errors as JSON object
  ///   • HTTP 409: duplicate conflicts (from JSON or known plain-text messages)
  ///   • Other codes: global error with best-effort message extraction
  Future<RegisterResultModel> submit({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String gender,
    required String idNumber,
    required DateTime dateOfBirth,
    required String email,
    required String password,
    required String role,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    final body = _buildRequestBody(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      gender: gender,
      idNumber: idNumber,
      dateOfBirth: dateOfBirth,
      email: email,
      password: password,
      role: role
    );

    try {
      final res = await http
          .post(url, headers: _jsonHeaders, body: body)
          .timeout(_timeout);

      final plainBody = res.body;
      final parsed = _tryParseJson(plainBody);

      // Fast-path: some backends return raw-text duplicates instead of JSON.
      final duplicate = _mapDuplicateFromPlainBody(plainBody);
      if (duplicate != null) {
        return RegisterResultModel.fieldErrors(duplicate);
      }

      // Success: 202 Accepted with a status payload.
      if (res.statusCode == 202) {
        final status = parsed?['status'] as String?;
        if (status == null) {
          return RegisterResultModel.global('Malformed success response from server.');
        }
        return RegisterResultModel.success(status);
      }

      // Map common codes → field/global errors
      switch (res.statusCode) {
        case 400:
        case 422:
          // Expecting field-level errors as a JSON object.
          return RegisterResultModel.fieldErrors(parsed);
        case 409:
          // Duplicate conflicts may come as JSON or the known plain text.
          if (parsed != null && parsed.isNotEmpty) {
            return RegisterResultModel.fieldErrors(parsed);
          }
          return RegisterResultModel.fieldErrors(
            duplicate ?? {'email': 'Email already in use'},
          );
        default:
          // Best-effort global error message.
          final message = (parsed?['message'] as String?) ??
              'Server error (${res.statusCode}). Please try again.';
          return RegisterResultModel.global(message);
      }
    } on TimeoutException {
      return RegisterResultModel.global('Request timed out. Please try again.');
    } on SocketException {
      return RegisterResultModel.global('Network error. Check your connection.');
    } catch (_) {
      return RegisterResultModel.global('Unexpected error. Please try again.');
    }
  }
}