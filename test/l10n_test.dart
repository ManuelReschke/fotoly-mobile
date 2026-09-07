import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/app_strings_de.dart';
import 'package:fotoly_mobile/l10n/app_strings_en.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/services/storage.dart';

void main() {
  test('default locale is German', () {
    expect(AppLocale.fromCode(null), AppLocale.de);
    expect(AppLocale.fromCode('de').strings, isA<AppStringsDe>());
    expect(const AppStringsDe().startBackup, 'Backup starten');
    expect(const AppStringsDe().allSecuredButton, 'Alles gesichert');
  });

  test('time-of-day greetings and status lines are localized', () {
    const de = AppStringsDe();
    expect(de.greetingForHour(8), 'Guten Morgen');
    expect(de.greetingForHour(14), 'Guten Tag');
    expect(de.greetingForHour(19), 'Guten Abend');
    expect(
      de.homeStatusLine(pendingCount: 2, securedCount: 1, hasFolders: true),
      contains('Fuchsbau'),
    );

    const en = AppStringsEn();
    expect(en.greetingForHour(8), 'Good morning');
    expect(
      en.homeStatusLine(pendingCount: 0, securedCount: 5, hasFolders: true),
      contains('up to date'),
    );
  });

  test('English file is separate and complete for key buttons', () {
    const en = AppStringsEn();
    expect(en.languageCode, 'en');
    expect(en.startBackup, 'Start backup');
    expect(en.allSecuredButton, 'All secured');
    expect(en.settingsTitle, 'Settings');
    expect(en.appVersionLabel('1.0.0 (1)'), 'Version 1.0.0 (1)');
    expect(
      const AppStringsDe().appVersionLabel('1.0.0 (1)'),
      'Version 1.0.0 (1)',
    );
    expect(en.mediaPermissionDenied, contains('Photo access'));
    expect(
      const AppStringsDe().mediaPermissionPermanentlyDenied,
      contains('blockiert'),
    );
    expect(en.foldersInaccessible, contains('Cannot access'));
    expect(const AppStringsDe().foldersInaccessible, contains('nicht lesbar'));
    expect(en.fullSyncButton, 'Full Sync');
    expect(const AppStringsDe().fullSyncConfirm2Start, 'Jetzt prüfen');
    expect(
      en.fullSyncResultSnack(
        checked: 2,
        removed: 1,
        skippedNoUuid: 0,
        errors: 0,
      ),
      contains('removed: 1'),
    );
  });

  test('locale controller persists selection', () async {
    final prefs = MemoryPrefsStore();
    final controller = LocaleController(prefs: prefs);
    await controller.load();
    expect(controller.locale, AppLocale.de);

    await controller.setLocale(AppLocale.en);
    expect(controller.locale, AppLocale.en);
    expect(await prefs.getString(kLocalePrefsKey), 'en');

    final reloaded = LocaleController(prefs: prefs);
    await reloaded.load();
    expect(reloaded.locale, AppLocale.en);
    expect(reloaded.strings.languageCode, 'en');
  });

  test('appearance strings exist in DE and EN', () {
    const de = AppStringsDe();
    const en = AppStringsEn();
    expect(de.appearanceSectionTitle, 'Erscheinungsbild');
    expect(de.appearanceSectionSubtitle, 'Hell, Dark oder System');
    expect(de.themeModeLight, 'Hell');
    expect(de.themeModeDark, 'Dark');
    expect(de.themeModeSystem, 'System');
    expect(en.appearanceSectionTitle, 'Appearance');
    expect(en.appearanceSectionSubtitle, 'Light, Dark, or System');
    expect(en.themeModeLight, 'Light');
    expect(en.themeModeDark, 'Dark');
    expect(en.themeModeSystem, 'System');
  });

  test('gallery strings exist in DE and EN', () {
    const de = AppStringsDe();
    const en = AppStringsEn();
    expect(de.navGallery, 'Galerie');
    expect(en.navGallery, 'Gallery');
    expect(de.galleryEmptyTitle, 'Noch keine Bilder');
    expect(en.galleryEmptyTitle, 'No photos yet');
    expect(de.retry, 'Erneut versuchen');
    expect(en.retry, 'Try again');
    expect(de.galleryLoadError, contains('nicht geladen'));
    expect(en.galleryImageLoadError, 'Image unavailable');
  });

  test('register and check-email copy exists in DE and EN', () {
    const de = AppStringsDe();
    const en = AppStringsEn();
    expect(de.registerLink, 'Noch kein Konto? Registrieren');
    expect(en.registerLink, 'No account yet? Register');
    expect(de.createAccount, 'Konto erstellen');
    expect(en.createAccount, 'Create account');
    expect(de.passwordMismatch, 'Die Passwörter stimmen nicht überein.');
    expect(en.passwordMismatch, 'Passwords do not match.');
    expect(de.checkEmailTitle, 'E-Mail prüfen');
    expect(en.checkEmailTitle, 'Check your email');
    expect(de.checkEmailBody('a@b.c'), contains('a@b.c'));
    expect(en.checkEmailBody('a@b.c'), contains('a@b.c'));
    expect(de.backToLogin, 'Zum Login');
    expect(en.backToLogin, 'Back to login');
  });
}
