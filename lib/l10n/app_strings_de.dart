import '../config/app_brand.dart';
import 'app_strings.dart';

/// German (default) UI strings.
class AppStringsDe extends AppStrings {
  const AppStringsDe();

  @override
  String get languageCode => 'de';

  @override
  String get languageName => 'Deutsch';

  @override
  String get appTitle => AppBrand.current.displayName;

  @override
  String get homeTitle => '${AppBrand.current.displayName} Backup';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get refreshScanTooltip => 'Ordner erneut scannen';

  @override
  String get settingsTooltip => 'Einstellungen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get logOut => 'Abmelden';

  @override
  String get navBackup => 'Backup';

  @override
  String get navGallery => 'Galerie';

  @override
  String get galleryTitle => 'Galerie';

  @override
  String get galleryEmptyTitle => 'Noch keine Bilder';

  @override
  String get galleryEmptyBody => 'Lade Fotos über den Backup-Tab hoch.';

  @override
  String get galleryLoadError => 'Bilder konnten nicht geladen werden.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get galleryRefreshTooltip => 'Galerie aktualisieren';

  @override
  String get gallerySortTooltip => 'Bildreihenfolge';

  @override
  String get gallerySortNewest => 'Neueste zuerst';

  @override
  String get gallerySortOldest => 'Älteste zuerst';

  @override
  String get galleryImageLoadError => 'Bild nicht verfügbar';

  @override
  String get navAlbums => 'Alben';

  @override
  String get albumsTitle => 'Alben';

  @override
  String get albumsEmptyTitle => 'Noch keine Alben';

  @override
  String get albumsEmptyBody =>
      'Erstelle ein Album, um Fotos zu sammeln, hochzuladen und zu teilen.';

  @override
  String get albumsRefreshTooltip => 'Alben aktualisieren';

  @override
  String get createAlbum => 'Neues Album';

  @override
  String get editAlbum => 'Album bearbeiten';

  @override
  String get deleteAlbum => 'Album löschen';

  @override
  String get deleteAlbumTitle => 'Album löschen?';

  @override
  String get deleteAlbumBody =>
      'Das Album wird entfernt. Die Fotos bleiben in deiner Bibliothek.';

  @override
  String get albumTitleLabel => 'Titel';

  @override
  String get albumDescriptionLabel => 'Beschreibung';

  @override
  String get albumPublicLabel => 'Öffentlich';

  @override
  String get albumPublicSubtitle => 'Sichtbar für alle mit dem Link';

  @override
  String get albumNsfwLabel => 'Sensibler Inhalt';

  @override
  String get albumNsfwSubtitle => 'Album als NSFW markieren';

  @override
  String get albumSortLabel => 'Bildreihenfolge';

  @override
  String get albumSortHelp =>
      'Gilt für die öffentliche Albumseite. In der App siehst du die neuesten Bilder zuerst.';

  @override
  String get albumSortNewest => 'Neueste zuerst';

  @override
  String get albumSortOldest => 'Älteste zuerst';

  @override
  String get albumPasswordLabel => 'Freigabe-Passwort';

  @override
  String get albumPasswordHint => 'Optional, für die öffentliche Seite';

  @override
  String get albumChangePassword => 'Passwort ändern oder entfernen';

  @override
  String get albumPasswordClearHint =>
      'Feld leeren, um das Passwort zu entfernen.';

  @override
  String get albumTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get albumSave => 'Speichern';

  @override
  String get albumCreated => 'Album erstellt';

  @override
  String get albumSaved => 'Album gespeichert';

  @override
  String get albumDeleted => 'Album gelöscht';

  @override
  String get albumLimitReached => 'Das Album-Limit deines Tarifs ist erreicht.';

  @override
  String get albumNotFound => 'Album nicht gefunden.';

  @override
  String get albumAuthError =>
      'Die Anmeldung ist abgelaufen. Bitte erneut anmelden.';

  @override
  String get albumSaveError => 'Album konnte nicht gespeichert werden.';

  @override
  String get albumDeleteError => 'Album konnte nicht gelöscht werden.';

  @override
  String get albumActionError => 'Das hat nicht geklappt.';

  @override
  String get albumPhotosEmptyTitle => 'Noch keine Bilder in diesem Album';

  @override
  String get albumPhotosEmptyBody =>
      'Lade neue Fotos hoch oder nimm welche aus der Bibliothek.';

  @override
  String get addPhotos => 'Hinzufügen';

  @override
  String get uploadNewPhotos => 'Neue Fotos hochladen';

  @override
  String get addExistingPhotos => 'Aus der Bibliothek';

  @override
  String get removeFromAlbum => 'Aus Album entfernen';

  @override
  String get removeFromAlbumBody =>
      'Das Foto bleibt in der Bibliothek und wird nur aus diesem Album genommen.';

  @override
  String get setAsCover => 'Als Cover';

  @override
  String get clearCover => 'Cover entfernen';

  @override
  String get coverUpdated => 'Cover gespeichert';

  @override
  String get copyAlbumLink => 'Link kopieren';

  @override
  String get albumLinkCopied => 'Link kopiert';

  @override
  String get openAlbumLink => 'Im Browser öffnen';

  @override
  String get albumCouldNotOpenLink => 'Link konnte nicht geöffnet werden.';

  @override
  String get uploadingPhotos => 'Fotos werden hochgeladen…';

  @override
  String uploadFinished({required int uploaded, required int failed}) {
    if (failed == 0) {
      return uploaded == 1
          ? '1 Foto hochgeladen'
          : '$uploaded Fotos hochgeladen';
    }
    return '$uploaded hochgeladen, $failed fehlgeschlagen';
  }

  @override
  String get addToAlbum => 'Ins Album';

  @override
  String selectedCount(int count) =>
      count == 1 ? '1 ausgewählt' : '$count ausgewählt';

  @override
  String photosAdded(int count) =>
      count == 1 ? '1 Foto hinzugefügt' : '$count Fotos hinzugefügt';

  @override
  String get photoRemoved => 'Aus dem Album entfernt';

  @override
  String get privateAlbum => 'Privat';

  @override
  String get publicAlbum => 'Öffentlich';

  @override
  String get nsfwBadge => 'NSFW';

  @override
  String get loadMore => 'Mehr laden';

  @override
  String get cancelAction => 'Abbrechen';

  @override
  String get albumActionsTooltip => 'Album-Aktionen';

  @override
  String get albumMembers => 'Mitglieder';

  @override
  String get albumCategories => 'Kategorien';

  @override
  String get albumMembersEmpty => 'Noch keine Mitglieder.';

  @override
  String get albumMembersHelp =>
      'Eingeladene Personen können dieses Album ansehen.';

  @override
  String get albumInviteLabel => 'Benutzername';

  @override
  String get albumInviteAction => 'Einladen';

  @override
  String get albumInviteSent => 'Einladung gesendet';

  @override
  String get albumAlreadyMember => 'Diese Person ist schon Mitglied.';

  @override
  String get albumMemberRemoved => 'Mitglied entfernt';

  @override
  String get albumRemoveMember => 'Entfernen';

  @override
  String get albumRemoveMemberTitle => 'Mitglied entfernen?';

  @override
  String get albumRemoveMemberBody =>
      'Die Person verliert den Zugriff auf dieses Album.';

  @override
  String get albumMemberRoleViewer => 'Kann ansehen';

  @override
  String get albumMemberOriginInvite => 'Eingeladen';

  @override
  String get albumMemberOriginLinkSave => 'Über Link gespeichert';

  @override
  String get albumMemberUserNotFound => 'Kein aktives Konto mit diesem Namen.';

  @override
  String get albumMemberNotFound => 'Mitglied nicht gefunden.';

  @override
  String get albumCannotInviteOwner =>
      'Du kannst dich selbst oder den Besitzer nicht einladen.';

  @override
  String get albumMemberLimit =>
      'Dieses Album hat die maximale Anzahl an Mitgliedern erreicht.';

  @override
  String get albumUsernameRequired => 'Bitte einen Benutzernamen eingeben.';

  @override
  String get albumUsernameTooLong => 'Der Benutzername ist zu lang.';

  @override
  String get albumMemberAmbiguous =>
      'Mehrere Konten heißen so. Wähle eines aus.';

  @override
  String get albumMemberInviteError => 'Einladung fehlgeschlagen.';

  @override
  String get albumMemberLoadError => 'Mitglieder konnten nicht geladen werden.';

  @override
  String get albumMemberRemoveError => 'Mitglied konnte nicht entfernt werden.';

  @override
  String get albumCategoriesUnknownHelp =>
      'Speichern ersetzt alle Kategorien dieses Albums. Fotoly liefert die bisherigen Zuordnungen nicht mit, deshalb startet die Auswahl leer.';

  @override
  String get albumCategoriesKnownHelp =>
      'Speichern ersetzt alle Kategorien dieses Albums.';

  @override
  String get albumCategoriesEmpty => 'Noch keine Kategorien.';

  @override
  String get albumCategoryPrivate => 'Privat';

  @override
  String get albumCategoryPublic => 'Öffentlich';

  @override
  String get albumCategoryPublicNeedsAlbum =>
      'Öffentliche Kategorien nur bei einem öffentlichen Album.';

  @override
  String get albumCategoryNameLabel => 'Neue private Kategorie';

  @override
  String get albumCategoryCreate => 'Anlegen';

  @override
  String get albumCategoryCreated => 'Kategorie angelegt';

  @override
  String get albumCategoryNameInvalid =>
      'Nur Buchstaben, Zahlen und Bindestriche.';

  @override
  String get albumCategoryNameRequired => 'Bitte einen Namen eingeben.';

  @override
  String get albumCategoryNameTooLong => 'Der Name ist zu lang.';

  @override
  String get albumCategoryExists =>
      'Eine private Kategorie mit diesem Namen gibt es schon.';

  @override
  String get albumCategorySave => 'Speichern';

  @override
  String get albumCategorySaved => 'Kategorien gespeichert';

  @override
  String get albumCategoryClear => 'Alle entfernen';

  @override
  String get albumCategoryReplaceTitle => 'Kategorien ersetzen?';

  @override
  String get albumCategoryReplaceBody =>
      'Die Auswahl ersetzt alle bisherigen Kategorien dieses Albums.';

  @override
  String get albumCategorySaveError =>
      'Kategorien konnten nicht gespeichert werden.';

  @override
  String get albumCategoryLoadError =>
      'Kategorien konnten nicht geladen werden.';

  @override
  String get albumCategoryCreateError =>
      'Kategorie konnte nicht angelegt werden.';

  @override
  String get albumCategoryTooMany => 'Höchstens 100 Kategorien.';

  @override
  String albumCategoryCount(int count) =>
      count == 1 ? '1 Album' : '$count Alben';

  @override
  String get loginSubtitle =>
      'Melde dich an, um Fotos auf ${AppBrand.current.websiteHost} zu sichern';

  @override
  String get emailLabel => 'E-Mail';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get signIn => 'Einloggen';

  @override
  String get orDivider => 'oder';

  @override
  String signInWith(String provider) => 'Mit $provider einloggen';

  @override
  String get advancedApiKey => 'Mit API-Schlüssel anmelden';

  @override
  String get apiKeyLabel => 'API-Schlüssel';

  @override
  String get apiKeyHint =>
      'Schlüssel aus den ${AppBrand.current.websiteHost}-Einstellungen einfügen';

  @override
  String get connectToPixelfox =>
      'Mit ${AppBrand.current.displayName} verbinden';

  @override
  String get loginFooterNote =>
      'Social Login öffnet den Browser. Den API-Schlüssel brauchst du nur noch für Skripte.';

  @override
  String get registerLink => 'Noch kein Konto? Registrieren';

  @override
  String get registerTitle => 'Konto erstellen';

  @override
  String get registerSubtitle =>
      'Nach der Registrierung schicken wir einen Aktivierungslink per E-Mail.';

  @override
  String get usernameLabel => 'Benutzername';

  @override
  String get passwordConfirmLabel => 'Passwort wiederholen';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get passwordMismatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get checkEmailTitle => 'E-Mail prüfen';

  @override
  String checkEmailBody(String email) =>
      'Wir haben einen Aktivierungslink an $email geschickt. Öffne den Link im Browser und logge dich danach hier ein.';

  @override
  String get backToLogin => 'Zum Login';

  @override
  String hiUser(String username) => 'Hallo, $username';

  @override
  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 11) return 'Guten Morgen';
    if (hour >= 11 && hour < 17) return 'Guten Tag';
    if (hour >= 17 && hour < 22) return 'Guten Abend';
    return 'Gute Nacht';
  }

  @override
  String homeStatusLine({
    required int pendingCount,
    required int securedCount,
    required bool hasFolders,
  }) {
    if (!hasFolders) return 'Bereit für deinen ersten Backup-Lauf';
    if (pendingCount > 0) {
      return pendingCount == 1
          ? '1 Foto wartet auf den Fuchsbau'
          : '$pendingCount Fotos warten auf den Fuchsbau';
    }
    if (securedCount > 0) return 'Alles ruhig im Bau — du bist up to date';
    return 'Ordner sind gewählt — warte auf Fotos';
  }

  @override
  String get tipPickFolders =>
      'Tipp: Öffne die Einstellungen und wähle die Ordner zum Sichern.';

  @override
  String get backingUp => 'Sichern…';

  @override
  String get startBackup => 'Backup starten';

  @override
  String secureNewCount(int count) =>
      count == 1 ? '1 neues sichern' : '$count neue sichern';

  @override
  String get allSecuredButton => 'Alles gesichert';

  @override
  String get snackPickFoldersFirst =>
      'Wähle zuerst Ordner in den Einstellungen.';

  @override
  String get snackNoImagesFound =>
      'Keine Bilder in den ausgewählten Ordnern gefunden.';

  @override
  String get snackNothingNew => 'Nichts Neues zum Hochladen';

  @override
  String get lookingForPhotos => 'Suche nach Fotos…';

  @override
  String get readyWhenYouAre => 'Bereit, wenn du es bist';

  @override
  String get readyBody =>
      'Wähle Ordner in den Einstellungen und starte ein Backup.\n'
      'Deine Fotos landen sicher im Fuchsbau.';

  @override
  String photosNotYetSecured(int count) => '$count Fotos noch nicht gesichert';

  @override
  String onePhotoNotYetSecured() => '1 Foto noch nicht gesichert';

  @override
  String alreadySafeOnPixelfox(int securedCount) =>
      '$securedCount bereits sicher auf ${AppBrand.current.displayName}';

  @override
  String notYetSecuredFile(String fileName) =>
      '$fileName — noch nicht gesichert';

  @override
  String andMore(int extra) => '…und $extra weitere';

  @override
  String get everythingSecured => 'Alles ist gesichert';

  @override
  String everythingSecuredBody(int securedCount) =>
      '$securedCount Foto${securedCount == 1 ? '' : 's'} in deinen Ordnern '
      'sind bereits auf ${AppBrand.current.displayName}.\n'
      'Neue Bilder erscheinen hier automatisch.';

  @override
  String get backingUpRightNow => 'Sichert gerade';

  @override
  String get allSafeInTheDen => 'Alles sicher im Bau!';

  @override
  String allPhotosSafeMessage(int completed) =>
      'Alle $completed Fotos sind sicher auf ${AppBrand.current.displayName} gelandet.';

  @override
  String get newPhotosShowAsPending =>
      'Neue Fotos erscheinen als „noch nicht gesichert“.';

  @override
  String get almostFailedTitle => 'Fast — ein paar sind entwischt';

  @override
  String get someUploadsFailed =>
      'Einige Uploads sind fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String uploadSummary(int completed, int failed, int total) =>
      '$completed ok · $failed fehlgeschlagen · $total gesamt';

  @override
  String get foldersToBackUp => 'Ordner zum Sichern';

  @override
  String get noFoldersSelectedYet => 'Noch keine Ordner ausgewählt';

  @override
  String foldersWatched(int count) => '$count Ordner beobachtet';

  @override
  String oneFolderWatched() => '1 Ordner beobachtet';

  @override
  String get foldersHelp =>
      'Nur Bilder aus diesen Ordnern werden zu ${AppBrand.current.displayName} hochgeladen.';

  @override
  String get webFolderHint =>
      'Web/Chrome: kein echter Ordnerauswahl-Dialog. Nutze Linux-Desktop oder ein Handy.';

  @override
  String get addPhotoFolderHint => 'Füge einen Foto-Ordner hinzu';

  @override
  String get removeFolderTooltip => 'Ordner entfernen';

  @override
  String get pickFolder => 'Ordner wählen';

  @override
  String get pickFolderNotOnWeb => 'Ordner wählen (nicht im Web)';

  @override
  String get pastePathLabel => 'Oder Pfad einfügen';

  @override
  String get pastePathLabelWeb => 'Pfad einfügen (nur UI im Web)';

  @override
  String get pastePathHint => '/storage/emulated/0/DCIM/Camera';

  @override
  String get pastePathHintWeb => '/home/you/Pictures';

  @override
  String get addPath => 'Pfad hinzufügen';

  @override
  String get targetAlbumTitle =>
      'Ziel-Album auf ${AppBrand.current.displayName}';

  @override
  String get targetAlbumSubtitle =>
      'Bilder aus diesem Ordner immer in dieses Album legen';

  @override
  String get noAlbumOption => 'Kein Album (Bibliothek)';

  @override
  String get noAlbumHint => 'Ohne Album-Zuordnung';

  @override
  String albumAssigned(String title) => 'Album: $title';

  @override
  String get changeAlbumTooltip => 'Album ändern';

  @override
  String get confirmFolder => 'Ordner speichern';

  @override
  String get loadingAlbums => 'Alben werden geladen…';

  @override
  String get couldNotLoadAlbums => 'Alben konnten nicht geladen werden.';

  @override
  String get folderPickerUnavailable =>
      'Ordnerauswahl im Browser nicht verfügbar. '
      'Nutze Android/iOS oder Linux-Desktop (make run / make run-linux).';

  @override
  String get noFolderSelected => 'Kein Ordner gewählt (abgebrochen).';

  @override
  String addedFolder(String path) => 'Ordner hinzugefügt: $path';

  @override
  String get pathSavedUiOnly =>
      'Pfad für UI-Tests gespeichert. Echter Ordner-Scan/Upload braucht die native App '
      '(Android, iOS oder Linux-Desktop).';

  @override
  String get couldNotRefreshStorage =>
      'Speicherbelegung konnte nicht aktualisiert werden.';

  @override
  String get languageSectionTitle => 'Sprache';

  @override
  String get languageSectionSubtitle => 'App-Sprache wählen';

  @override
  String get appearanceSectionTitle => 'Erscheinungsbild';

  @override
  String get appearanceSectionSubtitle => 'Hell, Dark oder System';

  @override
  String get themeModeLight => 'Hell';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeSystem => 'System';

  @override
  String get fullSyncTitle => 'Full Sync';

  @override
  String get fullSyncSubtitle =>
      'Prüft, ob gesicherte Fotos noch auf ${AppBrand.current.displayName} liegen. '
      'Fehlende Einträge werden lokal freigegeben und beim nächsten Backup neu hochgeladen.';

  @override
  String get fullSyncButton => 'Full Sync';

  @override
  String get fullSyncConfirm1Title => 'Full Sync';

  @override
  String get fullSyncConfirm1Body =>
      'Jedes lokal als gesichert markierte Foto mit ${AppBrand.current.displayName}-ID wird geprüft. '
      'Bilder, die auf ${AppBrand.current.displayName} fehlen, werden aus der lokalen „bereits hochgeladen“-Liste entfernt, '
      'damit sie beim nächsten Backup erneut hochgeladen werden können. '
      'Während des Checks werden keine Dateien hochgeladen.';

  @override
  String get fullSyncConfirm1Continue => 'Weiter';

  @override
  String get fullSyncConfirm2Title => 'Full Sync starten?';

  @override
  String get fullSyncConfirm2Body =>
      'Bei vielen Fotos kann das eine Weile dauern. Wirklich starten?';

  @override
  String get fullSyncConfirm2Start => 'Jetzt prüfen';

  @override
  String get fullSyncCancel => 'Abbrechen';

  @override
  String fullSyncProgress(int checked, int total) => 'Prüfe… $checked / $total';

  @override
  String fullSyncResultSnack({
    required int checked,
    required int removed,
    required int skippedNoUuid,
    required int errors,
  }) =>
      'Geprüft: $checked · entfernt: $removed · ohne ID: $skippedNoUuid · Fehler: $errors';

  @override
  String get fullSyncBusyBackup =>
      'Full Sync ist während eines laufenden Backups nicht möglich.';

  @override
  String get fullSyncAuthFailed =>
      'API-Schlüssel ungültig — Full Sync abgebrochen.';

  @override
  String get fullSyncNothingToCheck =>
      'Keine prüfbaren Einträge (keine ${AppBrand.current.displayName}-IDs im Ledger).';

  @override
  String appVersionLabel(String version) => 'Version $version';

  @override
  String get mediaPermissionDenied =>
      'Foto-Zugriff wird benötigt, um deine Backup-Ordner zu lesen. Bitte erlauben, wenn gefragt.';

  @override
  String get mediaPermissionPermanentlyDenied =>
      'Foto-Zugriff ist blockiert. Öffne die Systemeinstellungen und erlaube Fotos für ${AppBrand.current.displayName}.';

  @override
  String get openSystemSettings => 'Einstellungen öffnen';

  @override
  String get foldersInaccessible =>
      'Ausgewählte Ordner sind nicht lesbar. Prüfe die Foto-Berechtigung und ob die Pfade noch existieren.';

  @override
  String get pixelfoxStorage => '${AppBrand.current.displayName} Speicher';

  @override
  String planLabel(String plan) => '$plan Plan';

  @override
  String get yourCloudQuota => 'Dein Cloud-Kontingent';

  @override
  String get storageUnavailable =>
      'Speicherbelegung für dieses Konto ist noch nicht verfügbar.';

  @override
  String ofQuota(String quota) => 'von $quota';

  @override
  String freeSpace(String amount) => '$amount frei';

  @override
  String imagesCount(int count) => count == 1 ? '1 Bild' : '$count Bilder';

  @override
  String get imagesOnPixelfox => 'Bilder auf ${AppBrand.current.displayName}';

  @override
  String get refreshUsageTooltip => 'Belegung aktualisieren';
}
