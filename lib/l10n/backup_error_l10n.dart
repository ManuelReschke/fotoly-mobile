import '../services/backup_errors.dart';
import 'app_strings.dart';

/// Maps a [BackupService] error code (or raw message) to user-facing copy.
String localizeBackupError(AppStrings strings, String? message) {
  if (message == null || message.isEmpty) {
    return strings.someUploadsFailed;
  }
  switch (message) {
    case BackupErrorCodes.foldersInaccessible:
      return strings.foldersInaccessible;
    case BackupErrorCodes.noFolders:
      return strings.snackPickFoldersFirst;
    case BackupErrorCodes.noImages:
      return strings.snackNoImagesFound;
    default:
      return message;
  }
}
