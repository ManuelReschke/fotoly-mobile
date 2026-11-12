import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/app.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/settings_service.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:fotoly_mobile/theme/theme_mode_controller.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

void main() {
  testWidgets('resume reloads the plan before the next inventory scan', (
    tester,
  ) async {
    final profile = File(
      'test/fixtures/profile_success.json',
    ).readAsStringSync();
    final store = MemorySecureStore();
    await store.write(kApiKeyStorageKey, 'stored-key');
    final fake = FakeApiHttp(profileStatus: 200, profileBody: profile);
    final auth = AuthService(
      secureStore: store,
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );
    await auth.bootstrap();
    expect(auth.profile?.maxUploadBytes, 52428800);

    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    final ledger = BackupLedger(prefs: prefs);
    final locale = LocaleController(prefs: prefs);
    final theme = ThemeModeController(prefs: prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<ThemeModeController>.value(value: theme),
          Provider<PrefsStore>.value(value: prefs),
          Provider<BackupLedger>.value(value: ledger),
        ],
        child: const PixelfoxApp(),
      ),
    );
    await tester.pump();

    fake.profileBody = profile.replaceFirst(
      '"max_upload_bytes": 52428800',
      '"max_upload_bytes": ${100 * 1024 * 1024}',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(auth.profile?.maxUploadBytes, 100 * 1024 * 1024);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
