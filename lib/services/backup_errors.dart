import 'pixelfox_api_client.dart';

/// Stable error codes stored on [BackupService] and mapped to l10n in the UI.
///
/// Services stay language-agnostic; screens/widgets call
/// [localizeBackupError] with the active [AppStrings].

abstract final class BackupErrorCodes {
  static const foldersInaccessible = 'error.folders_inaccessible';
  static const noFolders = 'error.no_folders';
  static const noImages = 'error.no_images';
  static const uploadsFailed = 'error.uploads_failed';
  static const scanFailed = 'error.scan_failed';
  static const offline = 'error.backup.offline';
}

/// True when the upload was rejected because the file exceeds the plan cap.
///
/// A full storage quota is a different 413 and stays a normal failure.
bool isUploadTooLargeError(Object error) {
  if (error is! PixelfoxApiException) return false;
  final blob = '${error.message}\n${error.body ?? ''}'.toLowerCase();
  if (blob.contains('quota_exceeded')) return false;
  return blob.contains('file exceeds') ||
      blob.contains('max_bytes') ||
      blob.contains('payload_too_large') ||
      blob.contains('file too large');
}

/// Bytes named in `File exceeds session max_bytes (N)`, when present.
int? maxBytesFromUploadError(Object error) {
  final text = error is PixelfoxApiException
      ? '${error.message} ${error.body ?? ''}'
      : error.toString();
  final match = RegExp(r'max_bytes \((\d+)\)').firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
