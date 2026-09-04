import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/config/app_brand.dart';
import 'package:pixelfox_mobile/l10n/locale_controller.dart';
import 'package:pixelfox_mobile/models/backup_status.dart';
import 'package:pixelfox_mobile/models/user_profile.dart';
import 'package:pixelfox_mobile/services/file_scanner.dart';
import 'package:pixelfox_mobile/services/storage.dart';
import 'package:pixelfox_mobile/theme/app_theme.dart';
import 'package:pixelfox_mobile/theme/theme_mode_controller.dart';
import 'package:pixelfox_mobile/widgets/appearance_card.dart';
import 'package:pixelfox_mobile/widgets/backup_status_view.dart';
import 'package:pixelfox_mobile/widgets/home_welcome_header.dart';
import 'package:pixelfox_mobile/widgets/language_card.dart';
import 'package:pixelfox_mobile/widgets/storage_usage_card.dart';
import 'package:provider/provider.dart';

Future<void> pumpL10n(
  WidgetTester tester,
  Widget child, {
  AppLocale locale = AppLocale.en,
}) async {
  final controller = LocaleController(prefs: MemoryPrefsStore());
  await controller.setLocale(locale);
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleController>.value(
      value: controller,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

Future<void> pumpAppearance(
  WidgetTester tester, {
  AppThemePreference preference = AppThemePreference.system,
}) async {
  final locale = LocaleController(prefs: MemoryPrefsStore());
  await locale.setLocale(AppLocale.en);
  final theme = ThemeModeController(prefs: MemoryPrefsStore());
  await theme.setPreference(preference);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<ThemeModeController>.value(value: theme),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: theme.materialThemeMode,
        home: const Scaffold(body: AppearanceCard()),
      ),
    ),
  );
}

void main() {
  testWidgets('home working state shows current file name', (tester) async {
    await pumpL10n(
      tester,
      const BackupStatusView(
        status: BackupStatus(
          phase: BackupPhase.working,
          currentFileName: 'sunset.jpg',
          completed: 1,
          total: 4,
        ),
      ),
    );

    expect(find.text('Backing up right now'), findsOneWidget);
    expect(find.text('sunset.jpg'), findsOneWidget);
    expect(find.textContaining('1 / 4'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
  });

  testWidgets('home success state shows warm completion message', (
    tester,
  ) async {
    await pumpL10n(
      tester,
      const BackupStatusView(
        status: BackupStatus(
          phase: BackupPhase.success,
          completed: 12,
          total: 12,
        ),
      ),
    );

    expect(find.text('All safe in the den!'), findsOneWidget);
    expect(find.textContaining('12 photos'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(AppBrand.current.markIcon), findsOneWidget);
  });

  testWidgets('idle state shows ready messaging when nothing scanned', (
    tester,
  ) async {
    await pumpL10n(tester, const BackupStatusView(status: BackupStatus.idle));

    expect(find.text('Ready when you are'), findsOneWidget);
  });

  testWidgets('storage usage card shows used of quota and free space', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 2,
      username: 'test',
      email: 'test@test.de',
      status: 'active',
      plan: 'free',
      storageUsedBytes: 1024 * 1024 * 100,
      storageQuotaBytes: 1024 * 1024 * 1024,
      storageRemainingBytes: 1024 * 1024 * 924,
      imageCount: 3,
    );

    await pumpL10n(tester, const StorageUsageCard(profile: profile));
    await tester.pumpAndSettle();

    expect(find.text('Fotoly storage'), findsOneWidget);
    expect(find.textContaining('of 1.0 GB'), findsOneWidget);
    expect(find.text('924 MB free'), findsOneWidget);
    expect(find.text('3 images'), findsOneWidget);
    expect(find.byType(ColoredBox), findsWidgets);
  });

  test('storage bar colors match pixelfox.cc CSS', () {
    expect(AppTheme.storageBarColor(0.0), AppTheme.storageLow);
    expect(AppTheme.storageBarColor(0.5), AppTheme.storageLow);
    expect(AppTheme.storageBarColor(0.7), AppTheme.storageMedium);
    expect(AppTheme.storageBarColor(0.89), AppTheme.storageMedium);
    expect(AppTheme.storageBarColor(0.9), AppTheme.storageHigh);
    expect(AppTheme.storageLow, const Color(0xFF10B981));
    expect(AppTheme.storageMedium, const Color(0xFFF59E0B));
    expect(AppTheme.storageHigh, const Color(0xFFEF4444));
  });

  testWidgets('idle with pending shows not-yet-secured list', (tester) async {
    await pumpL10n(
      tester,
      const BackupStatusView(
        status: BackupStatus.idle,
        securedCount: 2,
        pending: [
          LocalImageFile(
            path: '/p/holiday.jpg',
            name: 'holiday.jpg',
            sizeBytes: 100,
          ),
          LocalImageFile(path: '/p/cat.png', name: 'cat.png', sizeBytes: 50),
        ],
      ),
    );

    expect(find.text('2 photos not yet secured'), findsOneWidget);
    expect(find.text('holiday.jpg — not yet secured'), findsOneWidget);
    expect(find.text('cat.png — not yet secured'), findsOneWidget);
    expect(find.textContaining('2 already safe'), findsOneWidget);
  });

  testWidgets('German locale shows German pending copy', (tester) async {
    await pumpL10n(
      tester,
      locale: AppLocale.de,
      const BackupStatusView(
        status: BackupStatus.idle,
        pending: [
          LocalImageFile(path: '/p/a.jpg', name: 'a.jpg', sizeBytes: 1),
        ],
      ),
    );

    expect(find.text('1 Foto noch nicht gesichert'), findsOneWidget);
    expect(find.text('a.jpg — noch nicht gesichert'), findsOneWidget);
  });

  testWidgets('appearance card lists three modes and selects Dark', (
    tester,
  ) async {
    await pumpAppearance(tester, preference: AppThemePreference.dark);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping Light updates ThemeModeController', (tester) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    final theme = ThemeModeController(prefs: MemoryPrefsStore());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<ThemeModeController>.value(value: theme),
        ],
        child: MaterialApp(home: const Scaffold(body: AppearanceCard())),
      ),
    );

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(theme.preference, AppThemePreference.light);
  });

  testWidgets('language card uses theme surface in dark mode', (tester) async {
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleController>.value(
        value: locale,
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: LanguageCard()),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.color, isNull);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.style?.color == AppTheme.deepNight,
      ),
      findsNothing,
    );
  });

  testWidgets('welcome header is a light card without a dark gradient', (
    tester,
  ) async {
    await pumpL10n(
      tester,
      HomeWelcomeHeader(
        username: 'fox',
        email: 'fox@test.de',
        pendingCount: 0,
        securedCount: 3,
        hasFolders: true,
        now: DateTime(2026, 8, 13, 20),
      ),
    );

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('fox'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final dec = w.decoration;
        return dec is BoxDecoration && dec.gradient != null;
      }),
      findsNothing,
    );
    final greeting = tester.widget<Text>(find.text('Good evening'));
    expect(greeting.style?.color, isNot(Colors.white));
  });
}
