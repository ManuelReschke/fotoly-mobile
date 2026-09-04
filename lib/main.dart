import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app.dart';
import 'l10n/locale_controller.dart';
import 'services/auth_service.dart';
import 'services/backup_ledger.dart';
import 'services/oauth_browser.dart';
import 'services/settings_service.dart';
import 'services/storage.dart';
import 'theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStore = FlutterSecureStore();
  final prefsStore = await SharedPrefsStore.create();

  final appLinks = AppLinks();
  final auth = AuthService(
    secureStore: secureStore,
    openAuthSession: (url, scheme) => openOAuthSession(
      authorizationUrl: url,
      callbackUrlScheme: scheme,
      launchUrl: (target) =>
          launchUrl(target, mode: LaunchMode.externalApplication),
      incomingLinks: appLinks.uriLinkStream,
    ),
  );
  final settings = SettingsService(prefs: prefsStore);
  final ledger = BackupLedger(prefs: prefsStore);
  final locale = LocaleController(prefs: prefsStore);
  final themeMode = ThemeModeController(prefs: prefsStore);

  await Future.wait([
    auth.bootstrap(),
    settings.load(),
    locale.load(),
    themeMode.load(),
  ]);
  await ledger.load(userId: auth.profile?.id);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<ThemeModeController>.value(value: themeMode),
        Provider<BackupLedger>.value(value: ledger),
      ],
      child: const PixelfoxApp(),
    ),
  );
}
