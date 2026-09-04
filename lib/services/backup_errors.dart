/// Stable error codes stored on [BackupService] and mapped to l10n in the UI.
///
/// Services stay language-agnostic; screens/widgets call
/// [localizeBackupError] with the active [AppStrings].
abstract final class BackupErrorCodes {
  static const foldersInaccessible = 'error.folders_inaccessible';
  static const noFolders = 'error.no_folders';
  static const noImages = 'error.no_images';
}
