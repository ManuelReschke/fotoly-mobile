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
  String get gallerySortTooltip;
  String get gallerySortNewest;
  String get gallerySortOldest;
  String get galleryImageLoadError;

  // —— Albums ——
  String get navAlbums;
  String get albumsTitle;
  String get albumsEmptyTitle;
  String get albumsEmptyBody;
  String get albumsRefreshTooltip;
  String get createAlbum;
  String get editAlbum;
  String get deleteAlbum;
  String get deleteAlbumTitle;
  String get deleteAlbumBody;
  String get albumTitleLabel;
  String get albumDescriptionLabel;
  String get albumPublicLabel;
  String get albumPublicSubtitle;
  String get albumNsfwLabel;
  String get albumNsfwSubtitle;
  String get albumSortLabel;
  String get albumSortHelp;
  String get albumSortNewest;
  String get albumSortOldest;
  String get albumPasswordLabel;
  String get albumPasswordHint;
  String get albumChangePassword;
  String get albumPasswordClearHint;
  String get albumTitleRequired;
  String get albumSave;
  String get albumCreated;
  String get albumSaved;
  String get albumDeleted;
  String get albumLimitReached;
  String get albumNotFound;
  String get albumAuthError;
  String get albumSaveError;
  String get albumDeleteError;
  String get albumActionError;
  String get albumPhotosEmptyTitle;
  String get albumPhotosEmptyBody;
  String get addPhotos;
  String get uploadNewPhotos;
  String get addExistingPhotos;
  String get removeFromAlbum;
  String get removeFromAlbumBody;
  String get setAsCover;
  String get clearCover;
  String get coverUpdated;
  String get copyAlbumLink;
  String get albumLinkCopied;
  String get openAlbumLink;
  String get albumCouldNotOpenLink;
  String get uploadingPhotos;
  String uploadFinished({required int uploaded, required int failed});
  String get addToAlbum;
  String selectedCount(int count);
  String photosAdded(int count);
  String get photoRemoved;
  String get privateAlbum;
  String get publicAlbum;
  String get nsfwBadge;
  String get loadMore;
  String get cancelAction;
  String get albumActionsTooltip;
  String get albumMembers;
  String get albumCategories;
  String get albumMembersEmpty;
  String get albumMembersHelp;
  String get albumInviteLabel;
  String get albumInviteAction;
  String get albumInviteSent;
  String get albumAlreadyMember;
  String get albumMemberRemoved;
  String get albumRemoveMember;
  String get albumRemoveMemberTitle;
  String get albumRemoveMemberBody;
  String get albumMemberRoleViewer;
  String get albumMemberOriginInvite;
  String get albumMemberOriginLinkSave;
  String get albumMemberUserNotFound;
  String get albumMemberNotFound;
  String get albumCannotInviteOwner;
  String get albumMemberLimit;
  String get albumUsernameRequired;
  String get albumUsernameTooLong;
  String get albumMemberAmbiguous;
  String get albumMemberInviteError;
  String get albumMemberLoadError;
  String get albumMemberRemoveError;
  String get albumCategoriesUnknownHelp;
  String get albumCategoriesKnownHelp;
  String get albumCategoriesEmpty;
  String get albumCategoryPrivate;
  String get albumCategoryPublic;
  String get albumCategoryPublicNeedsAlbum;
  String get albumCategoryNameLabel;
  String get albumCategoryCreate;
  String get albumCategoryCreated;
  String get albumCategoryNameInvalid;
  String get albumCategoryNameRequired;
  String get albumCategoryNameTooLong;
  String get albumCategoryExists;
  String get albumCategorySave;
  String get albumCategorySaved;
  String get albumCategoryClear;
  String get albumCategoryReplaceTitle;
  String get albumCategoryReplaceBody;
  String get albumCategorySaveError;
  String get albumCategoryLoadError;
  String get albumCategoryCreateError;
  String get albumCategoryTooMany;
  String albumCategoryCount(int count);

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
  String get registerLink;
  String get registerTitle;
  String get registerSubtitle;
  String get usernameLabel;
  String get passwordConfirmLabel;
  String get createAccount;
  String get passwordMismatch;
  String get checkEmailTitle;
  String checkEmailBody(String email);
  String get backToLogin;

  // —— Errors (API copy and client checks) ——
  String get enterEmailPassword;
  String get enterUsernameEmailPassword;
  String get enterApiKey;
  String get invalidCredentials;
  String get loginFailed;
  String get loginDisabled;
  String get registrationFailed;
  String get registrationDisabled;
  String get emailAlreadyRegistered;
  String get passwordTooShort;
  String get usernameTooShort;
  String get invalidEmail;
  String get invalidRegistration;
  String get requestInvalid;
  String get accountNotActivated;
  String get accountDisabled;
  String get accountInactive;
  String get socialLoginUnavailable;
  String get socialLoginCancelled;
  String get socialLoginFailed;
  String get socialLoginBrowserFailed;
  String get socialLoginTimedOut;
  String get socialLoginCodeInvalid;
  String get socialLoginNotConfigured;
  String get sessionExpired;
  String get invalidApiKey;
  String get couldNotLoadProfile;
  String get uploadSessionFailed;
  String get uploadFailed;
  String get fileTooLarge;
  String get networkError;
  String get scanFailed;
  String get folderPickFailed;
  String get genericError;

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

  /// One-tap action that adds the device camera folder.
  String get secureOwnMedia;

  /// Secondary empty-state action that opens folder settings.
  String get chooseAnotherFolder;

  /// Shown when the standard camera directory is not on this device.
  String get cameraFolderNotFound;
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
