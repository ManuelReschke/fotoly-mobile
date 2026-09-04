import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/services/storage.dart';
import 'package:pixelfox_mobile/theme/app_theme.dart';
import 'package:pixelfox_mobile/theme/theme_mode_controller.dart';
import 'package:provider/provider.dart';

void main() {
  test('fromCode default is system; garbage is light', () {
    expect(AppThemePreference.fromCode(null), AppThemePreference.system);
    expect(AppThemePreference.fromCode('system'), AppThemePreference.system);
    expect(AppThemePreference.fromCode('light'), AppThemePreference.light);
    expect(AppThemePreference.fromCode('dark'), AppThemePreference.dark);
    expect(AppThemePreference.fromCode('nope'), AppThemePreference.light);
    expect(AppThemePreference.system.materialThemeMode, ThemeMode.system);
    expect(AppThemePreference.light.materialThemeMode, ThemeMode.light);
    expect(AppThemePreference.dark.materialThemeMode, ThemeMode.dark);
  });

  test('load with empty prefs is system', () async {
    final controller = ThemeModeController(prefs: MemoryPrefsStore());
    await controller.load();
    expect(controller.preference, AppThemePreference.system);
    expect(controller.materialThemeMode, ThemeMode.system);
  });

  test('setPreference persists and survives reload', () async {
    final prefs = MemoryPrefsStore();
    final controller = ThemeModeController(prefs: prefs);
    await controller.load();

    await controller.setPreference(AppThemePreference.dark);
    expect(controller.preference, AppThemePreference.dark);
    expect(await prefs.getString(kThemeModePrefsKey), 'dark');

    final reloaded = ThemeModeController(prefs: prefs);
    await reloaded.load();
    expect(reloaded.preference, AppThemePreference.dark);
    expect(reloaded.materialThemeMode, ThemeMode.dark);
  });

  test('unchanged setPreference does not rewrite prefs', () async {
    final prefs = MemoryPrefsStore();
    final controller = ThemeModeController(prefs: prefs);
    await controller.setPreference(AppThemePreference.light);
    await prefs.setString(kThemeModePrefsKey, 'sentinel');
    await controller.setPreference(AppThemePreference.light);
    expect(await prefs.getString(kThemeModePrefsKey), 'sentinel');
  });

  testWidgets('MaterialApp themeMode follows the controller', (tester) async {
    final controller = ThemeModeController(prefs: MemoryPrefsStore());
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeModeController>.value(
        value: controller,
        child: Builder(
          builder: (context) {
            final theme = context.watch<ThemeModeController>();
            return MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: theme.materialThemeMode,
              home: const Scaffold(body: Text('x')),
            );
          },
        ),
      ),
    );

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await controller.setPreference(AppThemePreference.dark);
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });
}
