import 'app_strings.dart';
import 'user_error_l10n.dart';

/// Maps a [BackupService] error code (or raw message) to user-facing copy.
String localizeBackupError(AppStrings strings, String? message) {
  return localizeUserError(
    strings,
    message,
    fallback: strings.someUploadsFailed,
  );
}
