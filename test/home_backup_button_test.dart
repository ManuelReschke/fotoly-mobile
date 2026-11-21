import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/models/upload_size_policy.dart';
import 'package:fotoly_mobile/screens/home_screen.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/backup_service.dart';
import 'package:fotoly_mobile/services/file_scanner.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/settings_service.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:fotoly_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

/// Phone width where "Premium freischalten" sits beside "Zurücksetzen".
const Size _phone = Size(360, 800);

void main() {
  late String sessionFixture;
  late String uploadFixture;

  setUpAll(() {
    sessionFixture = File(
      'test/fixtures/upload_session.json',
    ).readAsStringSync();
    uploadFixture = File('test/fixtures/upload_result.json').readAsStringSync();
  });

  Future<void> pumpSuccessHome(
    WidgetTester tester, {
    required int oversizedBytes,
  }) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.de);
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final limit = 25 * 1024 * 1024;
    final backup = BackupService(
      settings: settings,
      scanner: FakeFileScanner([
        const LocalImageFile(
          path: '/photos/ok.jpg',
          name: 'ok.jpg',
          sizeBytes: 4,
        ),
        LocalImageFile(
          path: '/photos/big.jpg',
          name: 'big.jpg',
          sizeBytes: oversizedBytes,
        ),
      ]),
      ledger: BackupLedger(prefs: MemoryPrefsStore()),
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          sessionStatus: 200,
          sessionBody: sessionFixture,
          uploadStatus: 200,
          uploadBody: uploadFixture,
        ),
      ),
      readBytes: (path) async => [1, 2, 3, 4],
      maxUploadBytes: () => limit,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      backup.dispose();
      settings.dispose();
      locale.dispose();
    });

    await backup.startBackup();
    expect(backup.status.isSuccess, isTrue);
    expect(backup.tooLargeCount, 1);

    final auth = AuthService(secureStore: MemorySecureStore());
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BackupService>.value(value: backup),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
      ),
    );
    await tester.pump();
  }

  void expectLabelFullyInsideFilledButton(WidgetTester tester, String label) {
    final button = find.widgetWithText(FilledButton, label);
    expect(button, findsOneWidget);
    final text = find.descendant(of: button, matching: find.text(label));
    expect(text, findsOneWidget);

    final buttonRect = tester.getRect(button);
    final textRect = tester.getRect(text);
    expect(textRect.left, greaterThanOrEqualTo(buttonRect.left));
    expect(textRect.top, greaterThanOrEqualTo(buttonRect.top));
    expect(textRect.right, lessThanOrEqualTo(buttonRect.right + 0.1));
    expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom + 0.1));

    final paragraph = tester.renderObject<RenderParagraph>(text);
    final style = paragraph.text.style ?? const TextStyle();
    expect(
      paragraph.textSize.height,
      lessThanOrEqualTo(paragraph.size.height + 0.5),
      reason:
          'text=${paragraph.textSize} box=${paragraph.size} '
          'button=$buttonRect styleSize=${style.fontSize}',
    );
    expect(
      paragraph.textSize.width,
      lessThanOrEqualTo(paragraph.size.width + 0.5),
      reason:
          'text=${paragraph.textSize} box=${paragraph.size} button=$buttonRect',
    );
    expect(style.fontSize, greaterThanOrEqualTo(14));
    expect(paragraph.didExceedMaxLines, isFalse);
    // Wrapped plan labels have to grow past the old fixed 56px height.
    expect(buttonRect.height, greaterThan(56));
  }

  testWidgets('the backup button starts the job with one preparatory scan', (
    tester,
  ) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.de);
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final auth = AuthService(secureStore: MemorySecureStore());
    final scanner = _CountingScanner();
    final backup = BackupService(
      settings: settings,
      scanner: scanner,
      ledger: BackupLedger(prefs: MemoryPrefsStore()),
      clientProvider: () {
        expect(scanner.calls, 1);
        return PixelfoxApiClient(
          apiKey: 'k',
          httpClient: FakeApiHttp(
            sessionStatus: 200,
            sessionBody: sessionFixture,
            uploadStatus: 200,
            uploadBody: uploadFixture,
          ),
        );
      },
      readBytes: (_) async => [1],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      backup.dispose();
      auth.dispose();
      settings.dispose();
      locale.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<BackupService>.value(value: backup),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Backup starten'));
    await tester.pumpAndSettle();

    expect(backup.status.isSuccess, isTrue);
    expect(scanner.calls, 2);
  });

  testWidgets('Premium freischalten stays inside the button beside reset', (
    tester,
  ) async {
    await pumpSuccessHome(tester, oversizedBytes: 30 * 1024 * 1024);

    expectLabelFullyInsideFilledButton(tester, 'Premium freischalten');
    final reset = find.widgetWithText(OutlinedButton, 'Zurücksetzen');
    expect(reset, findsOneWidget);
    expect(
      tester.getSize(reset).height,
      tester
          .getSize(find.widgetWithText(FilledButton, 'Premium freischalten'))
          .height,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('longer plan labels stay inside the button beside reset', (
    tester,
  ) async {
    await pumpSuccessHome(tester, oversizedBytes: 60 * 1024 * 1024);
    expectLabelFullyInsideFilledButton(tester, 'Premium Max freischalten');
    expect(tester.takeException(), isNull);
  });

  testWidgets('files beyond every plan keep their label inside the button', (
    tester,
  ) async {
    await pumpSuccessHome(tester, oversizedBytes: kPremiumMaxUploadBytes + 1);
    expectLabelFullyInsideFilledButton(tester, 'Für keinen Tarif klein genug');
    expect(tester.takeException(), isNull);
  });
}

class _CountingScanner implements FileScanner {
  int calls = 0;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async {
    calls++;
    return const [
      LocalImageFile(
        path: '/photos/photo.jpg',
        name: 'photo.jpg',
        sizeBytes: 1,
      ),
    ];
  }
}
