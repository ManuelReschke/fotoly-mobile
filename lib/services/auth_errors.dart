/// Stable auth error codes stored on [AuthService] and mapped in the UI.
///
/// The service stays language-agnostic. Screens call [localizeUserError].
abstract final class AuthErrorCodes {
  static const credentialsRequired = 'error.auth.credentials_required';
  static const registerFieldsRequired = 'error.auth.register_fields_required';
  static const apiKeyRequired = 'error.auth.api_key_required';
  static const socialUnavailable = 'error.auth.social_unavailable';
  static const socialCancelled = 'error.auth.social_cancelled';
  static const loginFailed = 'error.auth.login_failed';
  static const registerFailed = 'error.auth.register_failed';
  static const socialFailed = 'error.auth.social_failed';
}
