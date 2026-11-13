import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/app.dart';
import 'package:fotoly_mobile/l10n/app_strings_de.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/settings_service.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:fotoly_mobile/theme/theme_mode_controller.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

void main() {
  late String sessionFixture;

  setUpAll(() {
    sessionFixture = File('test/fixtures/auth_session.json').readAsStringSync();
  });

  Future<AuthService> offlineAuth({
    required MemorySecureStore secure,
    required MemoryPrefsStore prefs,
  }) async {
    final online = AuthService(
      secureStore: secure,
      prefs: prefs,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: FakeApiHttp(loginStatus: 200, loginBody: sessionFixture),
      ),
    );
    expect(
      await online.loginWithPassword('pete@example.com', 'secret12'),
      isTrue,
    );
    online.dispose();

    final auth = AuthService(
      secureStore: secure,
      prefs: prefs,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: FakeApiHttp(
          transportError: http.ClientException('offline'),
        ),
      ),
    );
    await auth.bootstrap();
    return auth;
  }

  testWidgets('login shows a prominent offline banner', (tester) async {
    final prefs = MemoryPrefsStore();
    final locale = LocaleController(prefs: prefs);
    await locale.setLocale(AppLocale.de);
    final theme = ThemeModeController(prefs: prefs);
    await theme.load();
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      prefs: prefs,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: FakeApiHttp(
          transportError: http.ClientException('offline'),
        ),
      ),
    );
    await auth.bootstrap();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<ThemeModeController>.value(value: theme),
        ],
        child: const PixelfoxApp(),
      ),
    );
    await tester.pump();

    expect(find.text(const AppStringsDe().offlineLoginBanner), findsOneWidget);
    expect(find.text('Einloggen'), findsOneWidget);
    expect(find.text(const AppStringsDe().offlineBanner), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    locale.dispose();
    theme.dispose();
  });

  testWidgets('offline session keeps the cached account under the banner', (
    tester,
  ) async {
    final prefs = MemoryPrefsStore();
    final locale = LocaleController(prefs: prefs);
    await locale.setLocale(AppLocale.de);
    final theme = ThemeModeController(prefs: prefs);
    await theme.load();
    final settings = SettingsService(prefs: prefs);
    final auth = await offlineAuth(secure: MemorySecureStore(), prefs: prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<ThemeModeController>.value(value: theme),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          Provider<BackupLedger>.value(value: BackupLedger(prefs: prefs)),
          Provider<PrefsStore>.value(value: prefs),
        ],
        child: const PixelfoxApp(),
      ),
    );
    await tester.pump();

    expect(find.text(const AppStringsDe().offlineBanner), findsOneWidget);
    expect(find.text('pixelpete'), findsOneWidget);
    expect(find.text(const AppStringsDe().offlineLoginBanner), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    locale.dispose();
    theme.dispose();
    settings.dispose();
  });
}
