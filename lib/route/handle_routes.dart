import 'package:flutter/material.dart';
import 'otp_route.dart';

/// ---------------------------------------------------------------------------
/// handleOtpRoute
/// Centralized route factory for OTP-related navigation.
///
/// Usage
/// -----
/// ```dart
/// onGenerateRoute: handleOtpRoute
/// ```
///
/// • Supports `/otp` route via [otpRoute].
/// • Falls back to a “Route not found” screen for unknown routes.
/// ---------------------------------------------------------------------------

/// Returns a [Route] for OTP screens based on [settings.name].
Route<dynamic> handleOtpRoute(RouteSettings settings) {
  switch (settings.name) {
    // -------------------------------------------------------------------------
    // Supported routes
    // -------------------------------------------------------------------------
    case '/otp':
      return otpRoute(settings);

    // -------------------------------------------------------------------------
    // Fallback for unknown routes
    // -------------------------------------------------------------------------
    default:
      return MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Route not found')),
        ),
      );
  }
}