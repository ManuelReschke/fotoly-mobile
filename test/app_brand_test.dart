import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/config/api_config.dart';
import 'package:fotoly_mobile/config/app_brand.dart';
import 'package:fotoly_mobile/config/app_info.dart';
import 'package:fotoly_mobile/l10n/app_strings_de.dart';
import 'package:fotoly_mobile/l10n/app_strings_en.dart';
import 'package:fotoly_mobile/theme/app_theme.dart';

void main() {
  tearDown(AppBrand.debugReset);

  test('fotoly is the default brand pack', () {
    expect(AppBrand.current, AppBrand.fotoly);
    expect(AppBrand.current.displayName, 'Fotoly');
    expect(AppBrand.current.websiteHost, 'fotoly.eu');
    expect(AppBrand.pixelfox.id, 'pixelfox');
    expect(AppBrand.pixelfox.displayName, 'Pixelfox');
    expect(AppBrand.pixelfox.websiteHost, 'pixelfox.cc');
    expect(AppBrand.pixelfox.apiBaseUrl, 'https://pixelfox.cc');
    expect(AppBrand.pixelfox.callbackUrlScheme, 'pixelfox');
    expect(AppBrand.pixelfox.appRedirectUri, 'pixelfox://auth/callback');
    expect(
      AppBrand.pixelfox.androidApplicationId,
      'cc.pixelfox.pixelfox_mobile',
    );
    expect(AppBrand.pixelfox.logoAsset, 'assets/brand/pixelfox-logo.png');
    expect(
      AppBrand.pixelfox.logoMarkAsset,
      'assets/brand/pixelfox-logo-32.png',
    );
    expect(AppBrand.pixelfox.apiKeyStorageKey, 'pixelfox_api_key');
    expect(AppBrand.pixelfox.accessTokenStorageKey, 'pixelfox_access_token');
    expect(AppBrand.pixelfox.selectedFoldersKey, 'pixelfox_selected_folders');
    expect(AppBrand.pixelfox.backupLedgerKey, 'pixelfox_backup_ledger_v1');
    expect(AppBrand.pixelfox.localePrefsKey, 'pixelfox_locale');
    expect(AppBrand.pixelfox.themeModePrefsKey, 'pixelfox_theme_mode');
  });

  test('fotoly pack uses its own host, scheme, assets and storage keys', () {
    const fotoly = AppBrand.fotoly;
    expect(fotoly.id, 'fotoly');
    expect(fotoly.displayName, 'Fotoly');
    expect(fotoly.websiteHost, 'fotoly.eu');
    expect(fotoly.apiBaseUrl, 'https://fotoly.eu');
    expect(fotoly.callbackUrlScheme, 'fotoly');
    expect(fotoly.appRedirectUri, 'fotoly://auth/callback');
    expect(fotoly.androidApplicationId, 'eu.fotoly.fotoly_mobile');
    expect(fotoly.logoAsset, 'assets/brand/fotoly-logo.png');
    expect(fotoly.logoMarkAsset, 'assets/brand/fotoly-logo-32.png');
    expect(fotoly.appIconAsset, 'assets/brand/fotoly-app-icon.png');
    expect(fotoly.wordmark, 'FOTOLY.EU');
    expect(AppBrand.pixelfox.wordmark, 'PIXELFOX.CC');
    expect(fotoly.apiKeyStorageKey, 'fotoly_api_key');
    expect(fotoly.backupLedgerKey, 'fotoly_backup_ledger_v1');
    expect(fotoly.localePrefsKey, 'fotoly_locale');
  });

  test('fromId maps flavor names and rejects unknown ids', () {
    expect(AppBrand.fromId('Pixelfox'), AppBrand.pixelfox);
    expect(AppBrand.fromId('FOTOLY'), AppBrand.fotoly);
    expect(() => AppBrand.fromId('unknown'), throwsArgumentError);
  });

  test('debug override switches ApiConfig, AppInfo and theme assets', () {
    AppBrand.debugOverride(AppBrand.fotoly);

    expect(AppBrand.current, AppBrand.fotoly);
    expect(ApiConfig.baseUrl, 'https://fotoly.eu');
    expect(ApiConfig.callbackUrlScheme, 'fotoly');
    expect(ApiConfig.appRedirectUri, 'fotoly://auth/callback');
    expect(AppInfo.websiteHost, 'fotoly.eu');
    expect(AppTheme.logoAsset, 'assets/brand/fotoly-logo.png');
    expect(AppTheme.logoMarkAsset, 'assets/brand/fotoly-logo-32.png');
  });

  test('localized copy follows the active brand', () {
    AppBrand.debugOverride(AppBrand.fotoly);
    const de = AppStringsDe();
    const en = AppStringsEn();

    expect(de.appTitle, 'Fotoly');
    expect(de.homeTitle, 'Fotoly Backup');
    expect(de.loginSubtitle, contains('fotoly.eu'));
    expect(de.apiKeyHint, contains('fotoly.eu'));
    expect(de.connectToPixelfox, 'Mit Fotoly verbinden');
    expect(de.alreadySafeOnPixelfox(3), contains('Fotoly'));
    expect(de.pixelfoxStorage, 'Fotoly Speicher');
    expect(de.imagesOnPixelfox, 'Bilder auf Fotoly');

    expect(en.appTitle, 'Fotoly');
    expect(en.loginSubtitle, contains('fotoly.eu'));
    expect(en.connectToPixelfox, 'Connect to Fotoly');
    expect(en.alreadySafeOnPixelfox(3), contains('Fotoly'));
    expect(en.pixelfoxStorage, 'Fotoly storage');
    expect(en.imagesOnPixelfox, 'Images on Fotoly');
    expect(en.foldersHelp, contains('Fotoly'));
    expect(en.targetAlbumTitle, contains('Fotoly'));
    expect(en.fullSyncSubtitle, contains('Fotoly'));
    expect(de.foldersHelp, contains('Fotoly'));
    expect(de.targetAlbumTitle, contains('Fotoly'));
    expect(de.mediaPermissionPermanentlyDenied, contains('Fotoly'));
    expect(de.foldersHelp, isNot(contains('Pixelfox')));
    expect(en.foldersHelp, isNot(contains('Pixelfox')));
  });
}
