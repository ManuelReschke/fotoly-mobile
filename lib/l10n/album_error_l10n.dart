import '../services/pixelfox_api_client.dart';
import 'app_strings.dart';

/// Maps a member or category API failure to user-facing copy.
String localizeAlbumSharingError(
  AppStrings strings,
  Object error, {
  required String fallback,
}) {
  if (error is AlbumMemberAmbiguousException) {
    return strings.albumMemberAmbiguous;
  }
  if (error is! PixelfoxApiException) return fallback;
  final body = '${error.body ?? ''} ${error.message}'.toLowerCase();
  if (body.contains('album member limit')) return strings.albumMemberLimit;
  if (body.contains('cannot invite the album owner')) {
    return strings.albumCannotInviteOwner;
  }
  if (body.contains('username must not exceed')) {
    return strings.albumUsernameTooLong;
  }
  if (body.contains('username is required')) {
    return strings.albumUsernameRequired;
  }
  if (body.contains('member not found')) return strings.albumMemberNotFound;
  if (body.contains('user not found')) return strings.albumMemberUserNotFound;
  if (body.contains('album not found')) return strings.albumNotFound;
  if (body.contains('already exists')) return strings.albumCategoryExists;
  if (body.contains('letters, digits')) return strings.albumCategoryNameInvalid;
  if (body.contains('category name is too long') ||
      body.contains('too many category')) {
    return body.contains('too many category')
        ? strings.albumCategoryTooMany
        : strings.albumCategoryNameTooLong;
  }
  if (body.contains('category name is required')) {
    return strings.albumCategoryNameRequired;
  }
  if (body.contains('public categories require')) {
    return strings.albumCategoryPublicNeedsAlbum;
  }
  if (error.statusCode == 401 || error.statusCode == 403) {
    return strings.albumAuthError;
  }
  return fallback;
}

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
