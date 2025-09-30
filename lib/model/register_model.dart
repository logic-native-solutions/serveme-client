import 'package:flutter/foundation.dart';

/// Holds field-level error messages & a global message from backend.
@immutable
class RegisterErrors {
  String? firstName;
  String? lastName;
  String? phoneNumber;
  String? gender;
  String? role;
  String? idNumber;
  String? dateOfBirth;
  String? email;
  String? password;
  String? message;

  void clear() {
    firstName = lastName = phoneNumber = gender = role =
        idNumber = dateOfBirth = email = password = message = null;
  }
}