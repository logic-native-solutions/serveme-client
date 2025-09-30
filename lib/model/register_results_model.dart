/// ---------------------------------------------------------------------------
/// RegisterResultModel
/// Immutable data class describing the outcome of a registration attempt.
///
/// Fields
/// ------
/// • [success] – `true` if registration succeeded.
/// • [sessionId] – session/token used for OTP verification.
/// • [message] – optional global banner message.
/// • Field-level errors: [firstName], [lastName], [phoneNumber], [gender],
///   [role], [idNumber], [dateOfBirth], [email], [password].
/// ---------------------------------------------------------------------------
class RegisterResultModel {
  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Indicates if the registration was successful.
  final bool success;

  /// Session identifier or token for OTP.
  final String? sessionId;

  /// Global banner or message from the server.
  final String? message;

  /// Validation error for the first name.
  final String? firstName;

  /// Validation error for the last name.
  final String? lastName;

  /// Validation error for the phone number.
  final String? phoneNumber;

  /// Validation error for gender.
  final String? gender;

  /// Validation error for role.
  final String? role;

  /// Validation error for ID number.
  final String? idNumber;

  /// Validation error for date of birth.
  final String? dateOfBirth;

  /// Validation error for email.
  final String? email;

  /// Validation error for password.
  final String? password;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a [RegisterResultModel] with explicit values.
  const RegisterResultModel({
    required this.success,
    this.sessionId,
    this.message,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.gender,
    this.role,
    this.idNumber,
    this.dateOfBirth,
    this.email,
    this.password,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Returns a result representing a successful registration with [sessionId].
  factory RegisterResultModel.success(String sessionId) =>
      RegisterResultModel(success: true, sessionId: sessionId);

  /// Returns a result containing field-level errors or a banner [message].
  factory RegisterResultModel.fieldErrors(Map<String, dynamic>? b) =>
      RegisterResultModel(
        success: false,
        message: b?['message'] as String?,
        firstName: b?['firstName'] as String?,
        lastName: b?['lastName'] as String?,
        phoneNumber: b?['phoneNumber'] as String?,
        gender: b?['gender'] as String?,
        role: b?['role'] as String?,
        idNumber: b?['idNumber'] as String?,
        dateOfBirth: b?['dateOfBirth'] as String?,
        email: b?['email'] as String?,
        password: b?['password'] as String?,
      );

  /// Returns a result representing a global error banner.
  factory RegisterResultModel.global(String message) =>
      RegisterResultModel(success: false, message: message);
}