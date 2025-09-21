import 'package:flutter/material.dart';
import 'package:client/view/otp/otp.dart';

/// ---------------------------------------------------------------------------
/// otpRoute
/// Centralized [Route] factory for the OTP verification screen.
///
/// Responsibilities
/// ----------------
/// • Extracts arguments from [RouteSettings.arguments]:
///   - `email`
///   - `phone`
///   - `sessionId`
///   - `backendBaseUrl`
/// • Builds a [MaterialPageRoute] that displays [OtpScreen] with these values.
/// ---------------------------------------------------------------------------

/// Returns a [MaterialPageRoute] for the OTP verification flow.
///
/// Expects [settings.arguments] to be a `Map<String, dynamic>` containing:
/// - `email`
/// - `phone`
/// - `sessionId`
/// - `backendBaseUrl`
Route<dynamic> otpRoute(RouteSettings settings) {
  // ---------------------------------------------------------------------------
  // Extract arguments safely
  // ---------------------------------------------------------------------------
  final args =
      (settings.arguments ?? const <String, dynamic>{}) as Map<String, dynamic>;

  final email = (args['email'] ?? '') as String;
  final phone = (args['phone'] ?? '') as String;
  final sessionId = (args['sessionId'] ?? '') as String;
  final backendBaseUrl = (args['backendBaseUrl'] ?? '') as String;

  // ---------------------------------------------------------------------------
  // Build and return the route
  // ---------------------------------------------------------------------------
  return MaterialPageRoute(
    builder: (_) => OtpScreen(
      email: email,
      phone: phone,
      sessionId: sessionId,
      backendBaseUrl: backendBaseUrl,
    ),
    settings: settings,
  );
}