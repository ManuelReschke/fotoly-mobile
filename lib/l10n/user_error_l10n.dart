import '../services/auth_errors.dart';
import '../services/backup_errors.dart';
import 'app_strings.dart';

/// Maps a service error code or an English API message to UI copy.
///
/// Unknown and technical messages use [fallback], so a German session does
/// not show raw exception text.
String localizeUserError(
  AppStrings strings,
  String? message, {
  required String fallback,
}) {
  if (message == null || message.trim().isEmpty) return fallback;
  return _mapKnown(strings, message.trim()) ?? fallback;
}

String? _mapKnown(AppStrings strings, String message) {
  switch (message) {
    case AuthErrorCodes.credentialsRequired:
      return strings.enterEmailPassword;
    case AuthErrorCodes.registerFieldsRequired:
      return strings.enterUsernameEmailPassword;
    case AuthErrorCodes.apiKeyRequired:
      return strings.enterApiKey;
    case AuthErrorCodes.socialUnavailable:
      return strings.socialLoginUnavailable;
    case AuthErrorCodes.socialCancelled:
      return strings.socialLoginCancelled;
    case AuthErrorCodes.loginFailed:
      return strings.loginFailed;
    case AuthErrorCodes.registerFailed:
      return strings.registrationFailed;
    case AuthErrorCodes.socialFailed:
      return strings.socialLoginFailed;
    case BackupErrorCodes.foldersInaccessible:
      return strings.foldersInaccessible;
    case BackupErrorCodes.noFolders:
      return strings.snackPickFoldersFirst;
    case BackupErrorCodes.noImages:
      return strings.snackNoImagesFound;
    case BackupErrorCodes.uploadsFailed:
      return strings.someUploadsFailed;
    case BackupErrorCodes.scanFailed:
      return strings.scanFailed;
    default:
      return _mapPhrase(strings, message.toLowerCase());
  }
}

String? _mapPhrase(AppStrings strings, String lower) {
  final safe = RegExp(r'^all (\d+) photos are safe on ');
  final safeMatch = safe.firstMatch(lower);
  if (safeMatch != null) {
    return strings.allPhotosSafeMessage(int.parse(safeMatch.group(1)!));
  }
  if (RegExp(r'^\d+ of \d+ uploads failed$').hasMatch(lower)) {
    return strings.someUploadsFailed;
  }
  if (lower.contains('invalid email or password')) {
    return strings.invalidCredentials;
  }
  if (lower.contains('email is already registered')) {
    return strings.emailAlreadyRegistered;
  }
  if (lower.contains('please activate your account')) {
    return strings.accountNotActivated;
  }
  if (lower.contains('account has been disabled')) {
    return strings.accountDisabled;
  }
  if (lower.contains('account is currently inactive')) {
    return strings.accountInactive;
  }
  if (lower.contains('login is currently disabled')) {
    return strings.loginDisabled;
  }
  if (lower.contains('registration is currently disabled')) {
    return strings.registrationDisabled;
  }
  if (lower.contains('password must be at least')) {
    return strings.passwordTooShort;
  }
  if (lower.contains('username must be at least')) {
    return strings.usernameTooShort;
  }
  if (lower.contains('username, email and password are required') ||
      lower.contains('please enter username, email and password')) {
    return strings.enterUsernameEmailPassword;
  }
  if (lower.contains('email and password are required') ||
      lower.contains('please enter email and password')) {
    return strings.enterEmailPassword;
  }
  if (lower.contains('invalid email')) return strings.invalidEmail;
  if (lower.contains('invalid registration')) {
    return strings.invalidRegistration;
  }
  if (lower.contains('invalid request payload')) return strings.requestInvalid;
  if (lower.contains('please enter your') && lower.contains('api key')) {
    return strings.enterApiKey;
  }
  if (lower.contains('invalid api key') || lower.contains('api key')) {
    return strings.invalidApiKey;
  }
  if (lower.contains('session expired') ||
      lower.contains('missing or invalid authentication')) {
    return strings.sessionExpired;
  }
  if (lower.contains('could not open the login browser')) {
    return strings.socialLoginBrowserFailed;
  }
  if (lower.contains('social login timed out') ||
      lower.contains('login timed out')) {
    return strings.socialLoginTimedOut;
  }
  if (lower.contains('social login was cancelled') ||
      lower.contains('login was cancelled')) {
    return strings.socialLoginCancelled;
  }
  if (lower.contains('not available on this device')) {
    return strings.socialLoginUnavailable;
  }
  if (lower.contains('login is not configured') ||
      lower.contains('unknown oauth provider') ||
      lower.contains('redirect_uri is not allowed')) {
    return strings.socialLoginNotConfigured;
  }
  if (lower.contains('invalid or expired code') ||
      lower.contains('code is required')) {
    return strings.socialLoginCodeInvalid;
  }
  if (lower.contains('social login failed')) return strings.socialLoginFailed;
  if (lower.contains('registration failed')) return strings.registrationFailed;
  if (lower.startsWith('login failed')) return strings.loginFailed;
  if (lower.contains('could not load profile') ||
      lower.contains('failed to load profile')) {
    return strings.couldNotLoadProfile;
  }
  if (lower.contains('could not load albums') ||
      lower.contains('failed to load albums')) {
    return strings.couldNotLoadAlbums;
  }
  if (lower.contains('could not load images') ||
      lower.contains('failed to load images')) {
    return strings.galleryLoadError;
  }
  if (lower.contains('could not create upload session') ||
      lower.contains('failed to create upload session')) {
    return strings.uploadSessionFailed;
  }
  if (lower.contains('file exceeds') || lower.contains('max_bytes')) {
    return strings.fileTooLarge;
  }
  if (lower.contains('upload failed')) return strings.uploadFailed;
  if (lower.contains('could not verify image')) return strings.genericError;
  if (lower.contains('database unavailable') ||
      lower.contains('connection') ||
      lower.contains('network')) {
    return strings.networkError;
  }
  return null;
}
