import '../services/pixelfox_api_client.dart';
import 'app_strings.dart';

/// Maps an album API failure to user-facing copy.
String localizeAlbumError(
  AppStrings strings,
  Object error, {
  required String fallback,
}) {
  if (error is! PixelfoxApiException) return fallback;
  final body = (error.body ?? '').toLowerCase();
  if (error.statusCode == 403 && body.contains('album limit')) {
    return strings.albumLimitReached;
  }
  if (error.statusCode == 401 || error.statusCode == 403) {
    return strings.albumAuthError;
  }
  if (error.statusCode == 404) return strings.albumNotFound;
  return fallback;
}
