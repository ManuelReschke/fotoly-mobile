import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/settings_screen.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/backup_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/settings_service.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:fotoly_mobile/theme/theme_mode_controller.dart';
import 'package:fotoly_mobile/widgets/premium_upsell_card.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

Future<void> pumpCard(
  WidgetTester tester,
  Widget child, {
  AppLocale locale = AppLocale.en,
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = LocaleController(prefs: MemoryPrefsStore());
  await controller.setLocale(locale);
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleController>.value(
      value: controller,
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

String profileWithPlan(String plan) {
  final json =
      jsonDecode(File('test/fixtures/profile_success.json').readAsStringSync())
          as Map<String, dynamic>;
  json['plan'] = plan;
  return jsonEncode(json);
}

void main() {
  testWidgets('premium card shows the offer and calls the action', (
    tester,
  ) async {
    var taps = 0;
    await pumpCard(
      tester,
      PremiumUpsellCard(onPressed: () => taps++),
      locale: AppLocale.de,
    );

    expect(find.text('Mehr Platz für deine Fotos'), findsOneWidget);
    expect(find.text('200 GB Speicher'), findsOneWidget);
    expect(find.text('Keine Werbung'), findsOneWidget);
    expect(find.text('50 Alben · 50 MB pro Foto'), findsOneWidget);
    expect(find.text('ab 3,33 €'), findsOneWidget);
    expect(find.text('Premium freischalten'), findsOneWidget);

    await tester.tap(find.byKey(const Key('premium-upsell-cta')));
    expect(taps, 1);
  });

  testWidgets('english copy names the monthly price', (tester) async {
    await pumpCard(tester, const PremiumUpsellCard(onPressed: _noop));

    expect(find.text('More room for your photos'), findsOneWidget);
    expect(find.text('from €3.33'), findsOneWidget);
    expect(find.text('Unlock Premium'), findsOneWidget);
  });

  testWidgets('settings shows the upsell only for a free account', (
    tester,
  ) async {
    await _pumpSettings(tester, plan: 'free');
    expect(find.text('Unlock Premium'), findsOneWidget);
    expect(find.text('Fotoly storage'), findsOneWidget);

    await _pumpSettings(tester, plan: 'premium');
    expect(find.text('Unlock Premium'), findsNothing);

    await _pumpSettings(tester, plan: 'premium_max');
    expect(find.text('Unlock Premium'), findsNothing);
  });
}

void _noop() {}

Future<void> _pumpSettings(WidgetTester tester, {required String plan}) async {
  final fake = FakeApiHttp(profileBody: profileWithPlan(plan));
  final auth = AuthService(
    secureStore: MemorySecureStore(),
    clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
      apiKey: apiKey,
      accessToken: accessToken,
      httpClient: fake,
    ),
  );
  final loggedIn = await auth.loginWithApiKey('k');
  expect(loggedIn, isTrue);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final settings = SettingsService(prefs: MemoryPrefsStore());
  final backup = BackupService(
    settings: settings,
    ledger: BackupLedger(prefs: MemoryPrefsStore()),
    clientProvider: () => auth.client!,
  );
  final locale = LocaleController(prefs: MemoryPrefsStore());
  await locale.setLocale(AppLocale.en);
  final theme = ThemeModeController(prefs: MemoryPrefsStore());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<ThemeModeController>.value(value: theme),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<BackupService>.value(value: backup),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}
