/// UI copy for one language. Each concrete language lives in its own file.
abstract class AppStrings {
  const AppStrings();

  /// BCP-47 language code, e.g. `de`, `en`.
  String get languageCode;

  /// Human label for the language picker.
  String get languageName;

  // —— App chrome ——
  String get appTitle;
  String get homeTitle;
  String get settingsTitle;
  String get refreshScanTooltip;
  String get settingsTooltip;
  String get reset;
  String get logOut;

  // —— Gallery ——
  String get navBackup;
  String get navGallery;
  String get galleryTitle;
  String get galleryEmptyTitle;
  String get galleryEmptyBody;
  String get galleryLoadError;
  String get retry;
  String get galleryRefreshTooltip;
  String get galleryImageLoadError;

  // —— Login ——
  String get loginSubtitle;
  String get emailLabel;
  String get passwordLabel;
  String get signIn;
  String get orDivider;
  String signInWith(String provider);
  String get advancedApiKey;
  String get apiKeyLabel;
  String get apiKeyHint;
  String get connectToPixelfox;
  String get loginFooterNote;

  // —— Home ——
  String hiUser(String username);

  /// Time-of-day greeting without name, e.g. "Guten Morgen".
  String greetingForHour(int hour);

  /// Short status line under the name on the home header.
  String homeStatusLine({
    required int pendingCount,
    required int securedCount,
    required bool hasFolders,
  });
  String get tipPickFolders;
  String get backingUp;
  String get startBackup;
  String secureNewCount(int count);
  String get allSecuredButton;
  String get snackPickFoldersFirst;
  String get snackNoImagesFound;
  String get snackNothingNew;

  // —— Backup status heroes ——
  String get lookingForPhotos;
  String get readyWhenYouAre;
  String get readyBody;
  String photosNotYetSecured(int count);
  String onePhotoNotYetSecured();
  String alreadySafeOnPixelfox(int securedCount);
  String notYetSecuredFile(String fileName);
  String andMore(int extra);
  String get everythingSecured;
  String everythingSecuredBody(int securedCount);
  String get backingUpRightNow;
  String get allSafeInTheDen;
  String allPhotosSafeMessage(int completed);
  String get newPhotosShowAsPending;
  String get almostFailedTitle;
  String get someUploadsFailed;
  String uploadSummary(int completed, int failed, int total);

  // —— Settings / folders ——
  String get foldersToBackUp;
  String get noFoldersSelectedYet;
  String foldersWatched(int count);
  String oneFolderWatched();
  String get foldersHelp;
  String get webFolderHint;
  String get addPhotoFolderHint;
  String get removeFolderTooltip;
  String get pickFolder;
  String get pickFolderNotOnWeb;
  String get pastePathLabel;
  String get pastePathLabelWeb;
  String get pastePathHint;
  String get pastePathHintWeb;
  String get addPath;
  String get targetAlbumTitle;
  String get targetAlbumSubtitle;
  String get noAlbumOption;
  String get noAlbumHint;
  String albumAssigned(String title);
  String get changeAlbumTooltip;
  String get confirmFolder;
  String get loadingAlbums;
  String get couldNotLoadAlbums;
  String get folderPickerUnavailable;
  String get noFolderSelected;
  String addedFolder(String path);
  String get pathSavedUiOnly;
  String get couldNotRefreshStorage;
  String get languageSectionTitle;
  String get languageSectionSubtitle;
  String get appearanceSectionTitle;
  String get appearanceSectionSubtitle;
  String get themeModeLight;
  String get themeModeDark;
  String get themeModeSystem;

  /// Footer under settings actions, e.g. "Version 1.0.0 (1)".
  String appVersionLabel(String version);
  String get mediaPermissionDenied;
  String get mediaPermissionPermanentlyDenied;
  String get openSystemSettings;

  /// Selected folders cannot be read (permission or missing path).
  String get foldersInaccessible;

  // —— Full Sync ——
  String get fullSyncTitle;
  String get fullSyncSubtitle;
  String get fullSyncButton;
  String get fullSyncConfirm1Title;
  String get fullSyncConfirm1Body;
  String get fullSyncConfirm1Continue;
  String get fullSyncConfirm2Title;
  String get fullSyncConfirm2Body;
  String get fullSyncConfirm2Start;
  String get fullSyncCancel;
  String fullSyncProgress(int checked, int total);
  String fullSyncResultSnack({
    required int checked,
    required int removed,
    required int skippedNoUuid,
    required int errors,
  });
  String get fullSyncBusyBackup;
  String get fullSyncAuthFailed;
  String get fullSyncNothingToCheck;

  // —— Storage ——
  String get pixelfoxStorage;
  String planLabel(String plan);
  String get yourCloudQuota;
  String get storageUnavailable;
  String ofQuota(String quota);
  String freeSpace(String amount);
  String imagesCount(int count);
  String get imagesOnPixelfox;
  String get refreshUsageTooltip;
}
