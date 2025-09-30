/// ---------------------------------------------------------------------------
/// LoginResultModel
/// Immutable data class representing the outcome of a login attempt.
///
/// Fields
/// ------
/// • [success] – `true` if login succeeded.
/// • [token] – issued access token on success.
/// • [emailError], [passwordError] – field-specific validation errors.
/// • [message] – optional global banner message.
/// ---------------------------------------------------------------------------
class LoginResultModel {
  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Indicates if the login attempt was successful.
  final bool success;

  /// The access token returned on success.
  final String? token;

  /// Validation error for the email field.
  final String? emailError;

  /// Validation error for the password field.
  final String? passwordError;

  /// Global banner or general error message.
  final String? message;

  // ---------------------------------------------------------------------------
  // Constructors
  // ---------------------------------------------------------------------------

  /// Creates a new [LoginResultModel] with explicit values.
  const LoginResultModel({
    required this.success,
    this.token,
    this.emailError,
    this.passwordError,
    this.message,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Returns a result representing a successful login with a [token].
  factory LoginResultModel.success(String token) =>
      LoginResultModel(success: true, token: token);

  /// Returns a result representing field-level validation errors.
  factory LoginResultModel.fieldErrors({
    String? emailError,
    String? passwordError,
    String? message,
  }) =>
      LoginResultModel(
        success: false,
        emailError: emailError,
        passwordError: passwordError,
        message: message,
      );

  /// Returns a result representing a global error banner.
  factory LoginResultModel.global(String message) =>
      LoginResultModel(success: false, message: message);
}