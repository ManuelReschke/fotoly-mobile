import '../config/app_brand.dart';
import 'app_strings.dart';

/// English UI strings.
class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  String get languageCode => 'en';

  @override
  String get languageName => 'English';

  @override
  String get appTitle => AppBrand.current.displayName;

  @override
  String get homeTitle => '${AppBrand.current.displayName} Backup';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get refreshScanTooltip => 'Refresh folder scan';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get reset => 'Reset';

  @override
  String get logOut => 'Log out';

  @override
  String get navBackup => 'Backup';

  @override
  String get navGallery => 'Gallery';

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get galleryEmptyTitle => 'No photos yet';

  @override
  String get galleryEmptyBody => 'Upload photos from the Backup tab.';

  @override
  String get galleryLoadError => 'Could not load images.';

  @override
  String get retry => 'Try again';

  @override
  String get galleryRefreshTooltip => 'Refresh gallery';

  @override
  String get galleryImageLoadError => 'Image unavailable';

  @override
  String get navAlbums => 'Albums';

  @override
  String get albumsTitle => 'Albums';

  @override
  String get albumsEmptyTitle => 'No albums yet';

  @override
  String get albumsEmptyBody =>
      'Create an album to collect, upload, and share photos.';

  @override
  String get albumsRefreshTooltip => 'Refresh albums';

  @override
  String get createAlbum => 'New album';

  @override
  String get editAlbum => 'Edit album';

  @override
  String get deleteAlbum => 'Delete album';

  @override
  String get deleteAlbumTitle => 'Delete album?';

  @override
  String get deleteAlbumBody =>
      'The album is removed. Photos stay in your library.';

  @override
  String get albumTitleLabel => 'Title';

  @override
  String get albumDescriptionLabel => 'Description';

  @override
  String get albumPublicLabel => 'Public';

  @override
  String get albumPublicSubtitle => 'Anyone with the link can view it';

  @override
  String get albumNsfwLabel => 'Sensitive content';

  @override
  String get albumNsfwSubtitle => 'Mark this album as NSFW';

  @override
  String get albumSortLabel => 'Photo order';

  @override
  String get albumSortHelp =>
      'Used on the public album page. This app shows the newest photos first.';

  @override
  String get albumSortNewest => 'Newest first';

  @override
  String get albumSortOldest => 'Oldest first';

  @override
  String get albumPasswordLabel => 'Share password';

  @override
  String get albumPasswordHint => 'Optional, for the public page';

  @override
  String get albumChangePassword => 'Change or remove password';

  @override
  String get albumPasswordClearHint => 'Leave empty to remove the password.';

  @override
  String get albumTitleRequired => 'Enter a title.';

  @override
  String get albumSave => 'Save';

  @override
  String get albumCreated => 'Album created';

  @override
  String get albumSaved => 'Album saved';

  @override
  String get albumDeleted => 'Album deleted';

  @override
  String get albumLimitReached => 'Your plan has reached its album limit.';

  @override
  String get albumNotFound => 'Album not found.';

  @override
  String get albumAuthError => 'Your session expired. Please sign in again.';

  @override
  String get albumSaveError => 'Could not save the album.';

  @override
  String get albumDeleteError => 'Could not delete the album.';

  @override
  String get albumActionError => 'That did not work.';

  @override
  String get albumPhotosEmptyTitle => 'No photos in this album yet';

  @override
  String get albumPhotosEmptyBody =>
      'Upload new photos or add some from your library.';

  @override
  String get addPhotos => 'Add';

  @override
  String get uploadNewPhotos => 'Upload new photos';

  @override
  String get addExistingPhotos => 'From library';

  @override
  String get removeFromAlbum => 'Remove from album';

  @override
  String get removeFromAlbumBody =>
      'The photo stays in your library and is only removed from this album.';

  @override
  String get setAsCover => 'Set as cover';

  @override
  String get clearCover => 'Remove cover';

  @override
  String get coverUpdated => 'Cover saved';

  @override
  String get copyAlbumLink => 'Copy link';

  @override
  String get albumLinkCopied => 'Link copied';

  @override
  String get openAlbumLink => 'Open in browser';

  @override
  String get albumCouldNotOpenLink => 'Could not open the link.';

  @override
  String get uploadingPhotos => 'Uploading photos…';

  @override
  String uploadFinished({required int uploaded, required int failed}) {
    if (failed == 0) {
      return uploaded == 1 ? '1 photo uploaded' : '$uploaded photos uploaded';
    }
    return '$uploaded uploaded, $failed failed';
  }

  @override
  String get addToAlbum => 'Add to album';

  @override
  String selectedCount(int count) =>
      count == 1 ? '1 selected' : '$count selected';

  @override
  String photosAdded(int count) =>
      count == 1 ? '1 photo added' : '$count photos added';

  @override
  String get photoRemoved => 'Removed from album';

  @override
  String get privateAlbum => 'Private';

  @override
  String get publicAlbum => 'Public';

  @override
  String get nsfwBadge => 'NSFW';

  @override
  String get loadMore => 'Load more';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get albumActionsTooltip => 'Album actions';

  @override
  String get albumMembers => 'Members';

  @override
  String get albumCategories => 'Categories';

  @override
  String get albumMembersEmpty => 'No members yet.';

  @override
  String get albumMembersHelp => 'Invited people can view this album.';

  @override
  String get albumInviteLabel => 'Username';

  @override
  String get albumInviteAction => 'Invite';

  @override
  String get albumInviteSent => 'Invitation sent';

  @override
  String get albumAlreadyMember => 'This person is already a member.';

  @override
  String get albumMemberRemoved => 'Member removed';

  @override
  String get albumRemoveMember => 'Remove';

  @override
  String get albumRemoveMemberTitle => 'Remove member?';

  @override
  String get albumRemoveMemberBody => 'They lose access to this album.';

  @override
  String get albumMemberRoleViewer => 'Can view';

  @override
  String get albumMemberOriginInvite => 'Invited';

  @override
  String get albumMemberOriginLinkSave => 'Saved from link';

  @override
  String get albumMemberUserNotFound => 'No active account with that name.';

  @override
  String get albumMemberNotFound => 'Member not found.';

  @override
  String get albumCannotInviteOwner =>
      'You cannot invite yourself or the album owner.';

  @override
  String get albumMemberLimit => 'This album has reached the member limit.';

  @override
  String get albumUsernameRequired => 'Enter a username.';

  @override
  String get albumUsernameTooLong => 'That username is too long.';

  @override
  String get albumMemberAmbiguous =>
      'Several accounts share that name. Choose one.';

  @override
  String get albumMemberInviteError => 'Could not send the invitation.';

  @override
  String get albumMemberLoadError => 'Could not load members.';

  @override
  String get albumMemberRemoveError => 'Could not remove the member.';

  @override
  String get albumCategoriesUnknownHelp =>
      'Saving replaces every category on this album. Fotoly does not return the current assignment, so the selection starts empty.';

  @override
  String get albumCategoriesKnownHelp =>
      'Saving replaces every category on this album.';

  @override
  String get albumCategoriesEmpty => 'No categories yet.';

  @override
  String get albumCategoryPrivate => 'Private';

  @override
  String get albumCategoryPublic => 'Public';

  @override
  String get albumCategoryPublicNeedsAlbum =>
      'Public categories need a public album.';

  @override
  String get albumCategoryNameLabel => 'New private category';

  @override
  String get albumCategoryCreate => 'Create';

  @override
  String get albumCategoryCreated => 'Category created';

  @override
  String get albumCategoryNameInvalid => 'Letters, digits, and hyphens only.';

  @override
  String get albumCategoryNameRequired => 'Enter a name.';

  @override
  String get albumCategoryNameTooLong => 'That name is too long.';

  @override
  String get albumCategoryExists =>
      'A private category with this name already exists.';

  @override
  String get albumCategorySave => 'Save';

  @override
  String get albumCategorySaved => 'Categories saved';

  @override
  String get albumCategoryClear => 'Remove all';

  @override
  String get albumCategoryReplaceTitle => 'Replace categories?';

  @override
  String get albumCategoryReplaceBody =>
      'This selection replaces every category on this album.';

  @override
  String get albumCategorySaveError => 'Could not save categories.';

  @override
  String get albumCategoryLoadError => 'Could not load categories.';

  @override
  String get albumCategoryCreateError => 'Could not create the category.';

  @override
  String get albumCategoryTooMany => 'At most 100 categories.';

  @override
  String albumCategoryCount(int count) =>
      count == 1 ? '1 album' : '$count albums';

  @override
  String get loginSubtitle =>
      'Sign in to back up photos to ${AppBrand.current.websiteHost}';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get orDivider => 'or';

  @override
  String signInWith(String provider) => 'Sign in with $provider';

  @override
  String get advancedApiKey => 'Sign in with API key';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get apiKeyHint =>
      'Paste key from ${AppBrand.current.websiteHost} settings';

  @override
  String get connectToPixelfox => 'Connect to ${AppBrand.current.displayName}';

  @override
  String get loginFooterNote =>
      'Social login opens the browser. The API key is only needed for scripts.';

  @override
  String get registerLink => 'No account yet? Register';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle =>
      'After you register we send an activation link by email.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordConfirmLabel => 'Confirm password';

  @override
  String get createAccount => 'Create account';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String checkEmailBody(String email) =>
      'We sent an activation link to $email. Open the link in your browser, then sign in here.';

  @override
  String get backToLogin => 'Back to login';

  @override
  String hiUser(String username) => 'Hi, $username';

  @override
  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 11) return 'Good morning';
    if (hour >= 11 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Hey night owl';
  }

  @override
  String homeStatusLine({
    required int pendingCount,
    required int securedCount,
    required bool hasFolders,
  }) {
    if (!hasFolders) return 'Ready for your first backup run';
    if (pendingCount > 0) {
      return pendingCount == 1
          ? '1 photo is waiting for the den'
          : '$pendingCount photos are waiting for the den';
    }
    if (securedCount > 0) return 'Den is quiet — you are up to date';
    return 'Folders picked — waiting for photos';
  }

  @override
  String get tipPickFolders =>
      'Tip: open Settings and choose which folders to secure.';

  @override
  String get backingUp => 'Backing up…';

  @override
  String get startBackup => 'Start backup';

  @override
  String secureNewCount(int count) =>
      count == 1 ? 'Secure 1 new' : 'Secure $count new';

  @override
  String get allSecuredButton => 'All secured';

  @override
  String get snackPickFoldersFirst => 'Pick folders in Settings first.';

  @override
  String get snackNoImagesFound => 'No images found in the selected folders.';

  @override
  String get snackNothingNew => 'Nothing new to upload';

  @override
  String get lookingForPhotos => 'Looking for photos…';

  @override
  String get readyWhenYouAre => 'Ready when you are';

  @override
  String get readyBody =>
      'Pick folders in Settings, then start a backup.\n'
      'Your photos will hop safely into the fox den.';

  @override
  String photosNotYetSecured(int count) => '$count photos not yet secured';

  @override
  String onePhotoNotYetSecured() => '1 photo not yet secured';

  @override
  String alreadySafeOnPixelfox(int securedCount) =>
      '$securedCount already safe on ${AppBrand.current.displayName}';

  @override
  String notYetSecuredFile(String fileName) => '$fileName — not yet secured';

  @override
  String andMore(int extra) => '…and $extra more';

  @override
  String get everythingSecured => 'Everything is secured';

  @override
  String everythingSecuredBody(int securedCount) =>
      '$securedCount photo${securedCount == 1 ? '' : 's'} in your folders '
      'already live on ${AppBrand.current.displayName}.\n'
      'Add new images and they will show up here.';

  @override
  String get backingUpRightNow => 'Backing up right now';

  @override
  String get allSafeInTheDen => 'All safe in the den!';

  @override
  String allPhotosSafeMessage(int completed) =>
      'All $completed photos landed safely on ${AppBrand.current.displayName}.';

  @override
  String get newPhotosShowAsPending =>
      'New photos will show as “not yet secured”.';

  @override
  String get almostFailedTitle => 'Almost — a few slipped away';

  @override
  String get someUploadsFailed => 'Some uploads failed. Try again.';

  @override
  String uploadSummary(int completed, int failed, int total) =>
      '$completed ok · $failed failed · $total total';

  @override
  String get foldersToBackUp => 'Folders to back up';

  @override
  String get noFoldersSelectedYet => 'No folders selected yet';

  @override
  String foldersWatched(int count) => '$count folders watched';

  @override
  String oneFolderWatched() => '1 folder watched';

  @override
  String get foldersHelp =>
      'Only images in these folders are uploaded to ${AppBrand.current.displayName}.';

  @override
  String get webFolderHint =>
      'Web/Chrome: no real folder pick. Use Linux desktop or a phone.';

  @override
  String get addPhotoFolderHint => 'Add a photo folder to get started';

  @override
  String get removeFolderTooltip => 'Remove folder';

  @override
  String get pickFolder => 'Pick folder';

  @override
  String get pickFolderNotOnWeb => 'Pick folder (not on web)';

  @override
  String get pastePathLabel => 'Or paste a folder path';

  @override
  String get pastePathLabelWeb => 'Paste a path (UI only on web)';

  @override
  String get pastePathHint => '/storage/emulated/0/DCIM/Camera';

  @override
  String get pastePathHintWeb => '/home/you/Pictures';

  @override
  String get addPath => 'Add path';

  @override
  String get targetAlbumTitle =>
      'Target album on ${AppBrand.current.displayName}';

  @override
  String get targetAlbumSubtitle =>
      'Always save photos from this folder into this album';

  @override
  String get noAlbumOption => 'No album (library)';

  @override
  String get noAlbumHint => 'No album assigned';

  @override
  String albumAssigned(String title) => 'Album: $title';

  @override
  String get changeAlbumTooltip => 'Change album';

  @override
  String get confirmFolder => 'Save folder';

  @override
  String get loadingAlbums => 'Loading albums…';

  @override
  String get couldNotLoadAlbums => 'Could not load albums.';

  @override
  String get folderPickerUnavailable =>
      'Folder picker is not available in the browser. '
      'Use Android/iOS or Linux desktop (make run / make run-linux).';

  @override
  String get noFolderSelected => 'No folder selected (dialog cancelled).';

  @override
  String addedFolder(String path) => 'Added folder: $path';

  @override
  String get pathSavedUiOnly =>
      'Path saved for UI testing. Real folder scan/upload needs a native app '
      '(Android, iOS, or Linux desktop).';

  @override
  String get couldNotRefreshStorage => 'Could not refresh storage usage.';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSectionSubtitle => 'Choose app language';

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get appearanceSectionSubtitle => 'Light, Dark, or System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeSystem => 'System';

  @override
  String get fullSyncTitle => 'Full Sync';

  @override
  String get fullSyncSubtitle =>
      'Checks that secured photos still exist on ${AppBrand.current.displayName}. '
      'Missing ones are cleared locally and re-uploaded on the next backup.';

  @override
  String get fullSyncButton => 'Full Sync';

  @override
  String get fullSyncConfirm1Title => 'Full Sync';

  @override
  String get fullSyncConfirm1Body =>
      'Every locally secured photo that has a ${AppBrand.current.displayName} ID will be checked. '
      'Images missing on ${AppBrand.current.displayName} are removed from the local “already uploaded” list '
      'so the next backup can upload them again. '
      'No files are uploaded during this check.';

  @override
  String get fullSyncConfirm1Continue => 'Continue';

  @override
  String get fullSyncConfirm2Title => 'Start Full Sync?';

  @override
  String get fullSyncConfirm2Body =>
      'This may take a while if many photos are secured. Start now?';

  @override
  String get fullSyncConfirm2Start => 'Check now';

  @override
  String get fullSyncCancel => 'Cancel';

  @override
  String fullSyncProgress(int checked, int total) =>
      'Checking… $checked / $total';

  @override
  String fullSyncResultSnack({
    required int checked,
    required int removed,
    required int skippedNoUuid,
    required int errors,
  }) =>
      'Checked: $checked · removed: $removed · no ID: $skippedNoUuid · errors: $errors';

  @override
  String get fullSyncBusyBackup =>
      'Full Sync is not available while a backup is running.';

  @override
  String get fullSyncAuthFailed => 'Invalid API key — Full Sync aborted.';

  @override
  String get fullSyncNothingToCheck =>
      'Nothing to check (no ${AppBrand.current.displayName} IDs in the ledger).';

  @override
  String appVersionLabel(String version) => 'Version $version';

  @override
  String get mediaPermissionDenied =>
      'Photo access is required to read your backup folders. Please allow it when asked.';

  @override
  String get mediaPermissionPermanentlyDenied =>
      'Photo access is blocked. Open system settings and allow photos for ${AppBrand.current.displayName}.';

  @override
  String get openSystemSettings => 'Open settings';

  @override
  String get foldersInaccessible =>
      'Cannot access the selected folders. Check photo permission and that the paths still exist.';

  @override
  String get pixelfoxStorage => '${AppBrand.current.displayName} storage';

  @override
  String planLabel(String plan) => '$plan plan';

  @override
  String get yourCloudQuota => 'Your cloud quota';

  @override
  String get storageUnavailable =>
      'Storage usage is not available for this account yet.';

  @override
  String ofQuota(String quota) => 'of $quota';

  @override
  String freeSpace(String amount) => '$amount free';

  @override
  String imagesCount(int count) => count == 1 ? '1 image' : '$count images';

  @override
  String get imagesOnPixelfox => 'Images on ${AppBrand.current.displayName}';

  @override
  String get refreshUsageTooltip => 'Refresh usage';
}
