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
  String get galleryImageLoadError => 'Bild nicht verfügbar';

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
