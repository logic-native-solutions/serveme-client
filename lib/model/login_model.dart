import 'package:flutter/foundation.dart';

/// Holds field-level and global error messages for the login flow.
class LoginErrors {
  String? emailError;
  String? passwordError;
  String? message;

  void clear() {
    emailError = null;
    passwordError = null;
    message = null;
  }
}