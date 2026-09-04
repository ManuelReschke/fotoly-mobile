# Theme Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Settings offers Hell / Dark / System, persisted locally, with a coherent dark look across Login, Home, and Settings.

**Architecture:** `ThemeModeController` (Prefs + Provider, same shape as `LocaleController`) drives `MaterialApp.themeMode`. `AppTheme.dark()` plus `cardTheme` / `ColorScheme.surfaceContainerLowest` replace hardcoded white/`deepNight` on in-scope surfaces. Spec: `docs/superpowers/specs/2026-08-13-theme-mode-design.md`.

**Tech Stack:** Flutter/Dart, Provider, `PrefsStore` / `MemoryPrefsStore`, manual DE/EN l10n.

## Global Constraints

- User-facing copy via `lib/l10n/` only (DE + EN)
- Default missing prefs key: `system`
- Invalid prefs string: `light`
- Preference lives in `ThemeModeController`, not `SettingsService`
- Brand orange, storage traffic-light, AppBar `deepNight`, white-on-orange buttons, home header white-on-gradient stay hardcoded
- No shared `SettingsCard` wrapper
- No theme transition animation
- `make check` before claiming done

## Files

- Create: `lib/theme/theme_mode_controller.dart` — preference enum + persisted controller
- Create: `test/theme_mode_controller_test.dart`
- Modify: `lib/theme/app_theme.dart` — `dark()` + card/input tokens on both themes
- Create: `test/app_theme_test.dart` — brightness / card-token smoke
- Modify: `lib/l10n/app_strings.dart`, `app_strings_de.dart`, `app_strings_en.dart`
- Modify: `test/l10n_test.dart`
- Modify: `lib/main.dart` — construct, load, provide controller
- Modify: `lib/app.dart` — `darkTheme` + `themeMode`
- Create: `lib/widgets/appearance_card.dart`
- Modify: `lib/screens/settings_screen.dart` — insert card; drop hardcoded card white
- Modify: `lib/widgets/language_card.dart`, `full_sync_card.dart`, `storage_usage_card.dart`, `folders_backup_card.dart`
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/widgets/backup_status_view.dart`
- Modify: `lib/widgets/album_picker_sheet.dart`
- Modify: `test/widget_test.dart` — AppearanceCard coverage

---

### Task 1: ThemeModeController

**Files:**
- Create: `lib/theme/theme_mode_controller.dart`
- Test: `test/theme_mode_controller_test.dart`

**Interfaces:**
- Consumes: `PrefsStore` (`getString` / `setString`) from `lib/services/storage.dart`
- Produces:
  - `const String kThemeModePrefsKey = 'pixelfox_theme_mode'`
  - `enum AppThemePreference { system, light, dark }`
  - `String get code` → `'system' | 'light' | 'dark'`
  - `static AppThemePreference fromCode(String? code)`
  - `ThemeMode get materialThemeMode`
  - `class ThemeModeController extends ChangeNotifier`
  - `ThemeModeController({required PrefsStore prefs})` — constructor param name `_prefs` internally; public constructor is `ThemeModeController({required this._prefs})` matching `LocaleController`, or `ThemeModeController({required PrefsStore prefs})` storing as `_prefs`
  - `AppThemePreference get preference`
  - `ThemeMode get materialThemeMode` (delegates to `preference.materialThemeMode`)
  - `static const List<AppThemePreference> supported`
  - `Future<void> load()`
  - `Future<void> setPreference(AppThemePreference preference)`

- [ ] **Step 1: Write the failing test**

Create `test/theme_mode_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/services/storage.dart';
import 'package:pixelfox_mobile/theme/theme_mode_controller.dart';

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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme_mode_controller_test.dart`

Expected: FAIL compiling — `theme_mode_controller.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/theme/theme_mode_controller.dart`:

```dart
import 'package:flutter/material.dart';

import '../services/storage.dart';

const String kThemeModePrefsKey = 'pixelfox_theme_mode';

enum AppThemePreference {
  system,
  light,
  dark;

  String get code => name;

  static AppThemePreference fromCode(String? code) {
    switch (code) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      case 'system':
        return AppThemePreference.system;
      case null:
        return AppThemePreference.system;
      default:
        return AppThemePreference.light;
    }
  }

  ThemeMode get materialThemeMode {
    switch (this) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeModeController extends ChangeNotifier {
  ThemeModeController({required PrefsStore prefs}) : _prefs = prefs;

  final PrefsStore _prefs;
  AppThemePreference _preference = AppThemePreference.system;

  AppThemePreference get preference => _preference;

  ThemeMode get materialThemeMode => _preference.materialThemeMode;

  /// Picker order: Hell, Dark, System.
  static const List<AppThemePreference> supported = [
    AppThemePreference.light,
    AppThemePreference.dark,
    AppThemePreference.system,
  ];

  Future<void> load() async {
    final raw = await _prefs.getString(kThemeModePrefsKey);
    _preference = AppThemePreference.fromCode(raw);
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    await _prefs.setString(kThemeModePrefsKey, preference.code);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme_mode_controller_test.dart`

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/theme/theme_mode_controller.dart test/theme_mode_controller_test.dart
git commit -m "feat(theme): persist Hell/Dark/System preference"
```

---

### Task 2: AppTheme.dark and card tokens

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Test: `test/app_theme_test.dart`

**Interfaces:**
- Consumes: existing `AppTheme` brand constants (`foxOrange`, `foxAmber`, `storageHigh`, `deepNight`, `softCream`)
- Produces:
  - `static ThemeData light()` — also sets `surfaceContainerLowest` to white and `cardTheme.color` to that token
  - `static ThemeData dark()` — `Brightness.dark`, scaffold `deepNight`, card token `Color(0xFF241C2E)`
  - both: AppBar `deepNight` + white foreground; filled buttons fox orange + white; `inputDecorationTheme.fillColor` = card token

- [ ] **Step 1: Write the failing test**

Create `test/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/theme/app_theme.dart';

void main() {
  test('light and dark themes have opposite brightness and distinct cards', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.surface, AppTheme.softCream);
    expect(dark.colorScheme.surface, AppTheme.deepNight);
    expect(light.cardTheme.color, Colors.white);
    expect(dark.cardTheme.color, const Color(0xFF241C2E));
    expect(light.inputDecorationTheme.fillColor, Colors.white);
    expect(dark.inputDecorationTheme.fillColor, const Color(0xFF241C2E));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app_theme_test.dart`

Expected: FAIL — `AppTheme.dark` is not defined.

- [ ] **Step 3: Write minimal implementation**

In `lib/theme/app_theme.dart`, replace `light()` and add `dark()`. Keep every existing brand constant. Shared chrome helper is fine if it stays in this file:

```dart
  static const Color darkCard = Color(0xFF241C2E);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: foxOrange,
      brightness: Brightness.light,
      primary: foxOrange,
      secondary: foxAmber,
      error: storageHigh,
      surface: softCream,
    ).copyWith(surfaceContainerLowest: Colors.white);
    return _base(scheme: scheme, scaffold: softCream, card: Colors.white);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: foxOrange,
      brightness: Brightness.dark,
      primary: foxOrange,
      secondary: foxAmber,
      error: storageHigh,
      surface: deepNight,
    ).copyWith(surfaceContainerLowest: darkCard);
    return _base(scheme: scheme, scaffold: deepNight, card: darkCard);
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: foxOrange.withValues(alpha: 0.15)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepNight,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: foxOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
```

Do not change `storageBarColor` or logo asset paths.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app_theme_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart test/app_theme_test.dart
git commit -m "feat(theme): add dark ThemeData and card tokens"
```

---

### Task 3: l10n strings

**Files:**
- Modify: `lib/l10n/app_strings.dart` (after `languageSectionSubtitle`)
- Modify: `lib/l10n/app_strings_de.dart`
- Modify: `lib/l10n/app_strings_en.dart`
- Test: `test/l10n_test.dart`

**Interfaces:**
- Consumes: existing `AppStrings` abstract getters
- Produces:
  - `String get appearanceSectionTitle`
  - `String get appearanceSectionSubtitle`
  - `String get themeModeLight`
  - `String get themeModeDark`
  - `String get themeModeSystem`

- [ ] **Step 1: Write the failing test**

Add to `test/l10n_test.dart` inside `main()`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n_test.dart`

Expected: FAIL — getters are not defined on `AppStrings`.

- [ ] **Step 3: Write minimal implementation**

In `lib/l10n/app_strings.dart`, immediately after `languageSectionSubtitle`:

```dart
  String get appearanceSectionTitle;
  String get appearanceSectionSubtitle;
  String get themeModeLight;
  String get themeModeDark;
  String get themeModeSystem;
```

In `lib/l10n/app_strings_de.dart`, after `languageSectionSubtitle`:

```dart
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
```

In `lib/l10n/app_strings_en.dart`, after `languageSectionSubtitle`:

```dart
  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get appearanceSectionSubtitle => 'Light, Dark, or System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeSystem => 'System';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n_test.dart`

Expected: PASS (including the new test).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart lib/l10n/app_strings_de.dart lib/l10n/app_strings_en.dart test/l10n_test.dart
git commit -m "feat(l10n): add appearance theme strings"
```

---

### Task 4: Wire MaterialApp

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Test: `test/theme_mode_controller_test.dart` (append widget test)

**Interfaces:**
- Consumes: `ThemeModeController.load`, `preference`, `materialThemeMode`, `setPreference`; `AppTheme.light()`, `AppTheme.dark()`
- Produces: app-wide `ChangeNotifierProvider<ThemeModeController>`; `MaterialApp.theme` / `darkTheme` / `themeMode`

- [ ] **Step 1: Write the failing test**

Append to `test/theme_mode_controller_test.dart`:

```dart
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
```

Add imports: `package:pixelfox_mobile/theme/app_theme.dart`, `package:provider/provider.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme_mode_controller_test.dart`

Expected: FAIL or compile error until `watch` import is present — if the test file compiles, the assertion on `themeMode` still documents the wiring contract. If the test already passes as a local `MaterialApp` (it will, because it constructs its own app), that is OK: this step locks the mapping. Then apply the same mapping in production files.

If the test passes immediately, do not rewrite it; proceed to Step 3 and apply the same structure in `main.dart` / `app.dart`.

- [ ] **Step 3: Wire production**

`lib/main.dart` — next to `LocaleController`:

```dart
  final locale = LocaleController(prefs: prefsStore);
  final themeMode = ThemeModeController(prefs: prefsStore);

  await Future.wait([
    auth.bootstrap(),
    settings.load(),
    ledger.load(),
    locale.load(),
    themeMode.load(),
  ]);

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
```

Import `theme/theme_mode_controller.dart`.

`lib/app.dart` `PixelfoxApp.build`:

```dart
    final locale = context.watch<LocaleController>();
    final themeMode = context.watch<ThemeModeController>();
    return MaterialApp(
      title: locale.strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode.materialThemeMode,
      locale: Locale(locale.locale.code),
      home: const _RootGate(),
    );
```

Import `theme/theme_mode_controller.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/theme_mode_controller_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/app.dart test/theme_mode_controller_test.dart
git commit -m "feat(theme): apply persisted themeMode on MaterialApp"
```

---

### Task 5: AppearanceCard

**Files:**
- Create: `lib/widgets/appearance_card.dart`
- Modify: `lib/screens/settings_screen.dart` — import + insert above `LanguageCard`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `ThemeModeController.supported`, `preference`, `setPreference`; `context.l10n` appearance strings; `AppTheme.foxOrange`
- Produces: `class AppearanceCard extends StatelessWidget` with `const AppearanceCard({super.key})`

- [ ] **Step 1: Write the failing test**

Add to `test/widget_test.dart`:

```dart
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

testWidgets('appearance card lists three modes and selects Dark', (tester) async {
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
      child: MaterialApp(
        home: const Scaffold(body: AppearanceCard()),
      ),
    ),
  );

  await tester.tap(find.text('Light'));
  await tester.pump();
  expect(theme.preference, AppThemePreference.light);
});
```

Add imports for `appearance_card.dart`, `theme_mode_controller.dart`, and `MultiProvider` if not already imported.

Do **not** change `pumpL10n` for isolated status widgets.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL — `AppearanceCard` does not exist.

- [ ] **Step 3: Implement card and insert in Settings**

Create `lib/widgets/appearance_card.dart`. Structure matches `LanguageCard`, but:

- Icon: `Icons.brightness_6` in a `workingBlue` 12% tile (same size 44)
- Title: `s.appearanceSectionTitle`
- Subtitle: `s.appearanceSectionSubtitle`
- Rows from `ThemeModeController.supported`
- Labels: `themeModeLight` / `themeModeDark` / `themeModeSystem` via a local switch
- Leading icons: `Icons.light_mode`, `Icons.dark_mode`, `Icons.brightness_auto`
- `onTap: () => controller.setPreference(mode)`
- Card `color`: omit (inherit `cardTheme`) or `Theme.of(context).colorScheme.surfaceContainerLowest`
- Title/subtitle/row text: `colorScheme.onSurface` / `onSurface.withValues(alpha: 0.55)`
- Unselected row fill: `onSurface.withValues(alpha: 0.03)`
- Unselected border: `onSurface.withValues(alpha: 0.06)`
- Selected row: fox orange 10% fill + orange 45% border + check icon (same as language)

```dart
String _label(AppStrings s, AppThemePreference mode) {
  switch (mode) {
    case AppThemePreference.light:
      return s.themeModeLight;
    case AppThemePreference.dark:
      return s.themeModeDark;
    case AppThemePreference.system:
      return s.themeModeSystem;
  }
}

IconData _icon(AppThemePreference mode) {
  switch (mode) {
    case AppThemePreference.light:
      return Icons.light_mode;
    case AppThemePreference.dark:
      return Icons.dark_mode;
    case AppThemePreference.system:
      return Icons.brightness_auto;
  }
}
```

In `lib/screens/settings_screen.dart`:

- import `../widgets/appearance_card.dart`
- above `const LanguageCard()`:

```dart
          const AppearanceCard(),
          const SizedBox(height: 12),
          const LanguageCard(),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/appearance_card.dart lib/screens/settings_screen.dart test/widget_test.dart
git commit -m "feat(settings): add appearance Hell/Dark/System card"
```

---

### Task 6: ColorScheme restyle

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/widgets/language_card.dart`
- Modify: `lib/widgets/full_sync_card.dart`
- Modify: `lib/widgets/storage_usage_card.dart`
- Modify: `lib/widgets/folders_backup_card.dart`
- Modify: `lib/screens/login_screen.dart`
- Modify: `lib/widgets/backup_status_view.dart`
- Modify: `lib/widgets/album_picker_sheet.dart`
- Test: `test/widget_test.dart` (append)

**Interfaces:**
- Consumes: `Theme.of(context).colorScheme` (`surface`, `onSurface`, `surfaceContainerLowest`); `AppTheme.cardTheme` from Task 2
- Produces: no new public types

**Rules (apply in every file below):**

| Was | Replace with |
|-----|----------------|
| `Card(..., color: Colors.white, shape: orange border…)` | Drop `color` and `shape` if they now match `cardTheme`; keep custom padding/children |
| `color: AppTheme.deepNight` on body text | `Theme.of(context).colorScheme.onSurface` |
| `AppTheme.deepNight.withValues(alpha: 0.55/0.6/0.7/0.75/0.85)` on muted text / outlined buttons | `onSurface.withValues(alpha: same)` |
| `Colors.white` card/tile fill (not icon-on-orange, not header-on-gradient) | `colorScheme.surfaceContainerLowest` |
| `backgroundColor: AppTheme.softCream` on album sheet | `Theme.of(context).colorScheme.surface` |

**Do not change:** fox orange / amber / storage bar colors; AppBar; `Colors.white` on folder-card gradient icon; filled-button spinner white; `home_welcome_header.dart`; `pixelfox_logo.dart` default white.

- [ ] **Step 1: Write the failing test**

Append to `test/widget_test.dart`:

```dart
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
```

Import `language_card.dart` if missing.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --name "language card uses theme surface"`

Expected: FAIL — `LanguageCard` still sets `color: Colors.white` and `deepNight` text.

- [ ] **Step 3: Restyle each in-scope file**

**`language_card.dart` / `full_sync_card.dart` / `storage_usage_card.dart` / `folders_backup_card.dart` / settings profile `Card`:**

At the top of `build`:

```dart
    final scheme = Theme.of(context).colorScheme;
```

- Remove `color: Colors.white` from `Card` (and `shape` if it duplicates `cardTheme`).
- Replace title `color: AppTheme.deepNight` with `scheme.onSurface`.
- Replace subtitle / muted with `scheme.onSurface.withValues(alpha: 0.55)` (keep existing alpha).
- Unselected row `Material` / border that used `deepNight` alpha 0.03 / 0.06 → `scheme.onSurface` same alphas.
- Outlined buttons (`FullSyncCard`, settings logout): `foregroundColor: scheme.onSurface.withValues(alpha: 0.75)` (or 0.85 where that was the old value).
- `folders_backup_card.dart`: keep `color: Colors.white` on the **folder icon** inside the orange gradient. Replace only the outer card white and body `deepNight` text. Path chips / empty-state fills that used `deepNight.withValues(alpha: 0.03)` become `onSurface` with the same alpha. Manual-path `TextField` fill `Colors.white` → omit or `scheme.surfaceContainerLowest`.

**`settings_screen.dart` profile card:** drop `color: Colors.white` and matching `shape` if `cardTheme` covers it. Gravatar `backgroundColor: scheme.onSurface.withValues(alpha: 0.06)`. Logout outlined button uses `scheme.onSurface.withValues(alpha: 0.75)`.

**`login_screen.dart`:** headline / subtitle / footer `deepNight` → `onSurface` (same alphas). Leave spinner `color: Colors.white`. Error text may stay `Colors.red.shade700` or use `colorScheme.error`.

**`album_picker_sheet.dart`:**

```dart
    backgroundColor: Theme.of(context).colorScheme.surface,
```

`_AlbumTile`: unselected `Colors.white` → `scheme.surfaceContainerLowest`; icon/title `deepNight` → `scheme.onSurface`; subtitle / unselected border alphas on `onSurface`.

**`backup_status_view.dart`:**

Add a file-private helper:

```dart
List<Color> _heroColors(BuildContext context, List<Color> light, List<Color> dark) {
  return Theme.of(context).brightness == Brightness.dark ? dark : light;
}
```

Replace each `_HeroCard` gradient:

| Light (current) | Dark |
|-----------------|------|
| `[0xFFFFE8D6, 0xFFFFF8F0]` | `[0xFF3A2A28, 0xFF2A1F24]` |
| `[0xFFFFE8D6, 0xFFFFF3E0]` | `[0xFF3D2C22, 0xFF33261C]` |
| `[0xFFD8F3DC, 0xFFE8F5E9]` | `[0xFF1B3A2A, 0xFF163028]` |
| `[0xFFD8E2DC, 0xFFE8F1F2]` | `[0xFF243038, 0xFF1C2830]` |
| `[0xFFD8F3DC, 0xFFB7E4C7]` | `[0xFF1B3A2A, 0xFF163028]` |
| `[0xFFFFE5D9, 0xFFFFCAD4]` | `[0xFF3A2228, 0xFF332028]` |

Keep the success radial `[0xFF95D5B2, 0xFF2D6A4F]` and fail accent `0xFF9B2226`.

Replace hero **body** `AppTheme.deepNight` text with `scheme.onSurface`. Leave white check / pets icons that sit on the dark-green radial. Working-file chip `Colors.white.withValues(alpha: 0.85)` → `scheme.surfaceContainerLowest.withValues(alpha: 0.85)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget_test.dart`

Expected: PASS, including `language card uses theme surface in dark mode`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/login_screen.dart \
  lib/widgets/language_card.dart lib/widgets/full_sync_card.dart \
  lib/widgets/storage_usage_card.dart lib/widgets/folders_backup_card.dart \
  lib/widgets/backup_status_view.dart lib/widgets/album_picker_sheet.dart \
  test/widget_test.dart
git commit -m "fix(theme): restyle surfaces for coherent dark mode"
```

---

### Task 7: Quality gate

**Files:** none new — verify the whole change.

**Interfaces:**
- Consumes: all previous tasks
- Produces: green `make check`

- [ ] **Step 1: Format**

Run: `make format`

- [ ] **Step 2: Analyze and test**

Run: `make check`

Expected: `flutter analyze` no issues; all tests pass.

If analyze flags `CardTheme` vs `CardThemeData`, use whichever the current Flutter SDK accepts (`CardThemeData` on recent 3.x). If `surfaceContainerLowest` is rejected, set it via `ColorScheme.fromSeed(...).copyWith(surfaceContainerLowest: card)` only — do not invent a parallel token.

- [ ] **Step 3: Manual smoke (when a device/desktop is available)**

- Settings: tap Hell, Dark, System — whole app updates immediately.
- Logout: Login screen follows the same mode.
- Cards stay readable (no white cards in Dark, no cream-on-cream in Hell).

If no device is available, say so; `make check` is still required.

- [ ] **Step 4: Commit only if format/check produced leftover diffs**

```bash
git add -u
git commit -m "chore: format theme mode changes"
```

Skip this commit if the working tree is clean.

---

## Self-review

| Spec requirement | Task |
|------------------|------|
| Hell / Dark / System picker | 5 |
| Persist locally | 1, 4 |
| Default system | 1 (`fromCode(null)` / empty load) |
| Invalid → light | 1 (`default:`) |
| `AppTheme.dark()` + MaterialApp wiring | 2, 4 |
| Appearance above Language | 5 |
| Same interaction as language | 5 |
| No snackbar | 5 (tap only `setPreference`) |
| ColorScheme restyle Login/Home/Settings/sheet | 6 |
| Brand colors stay | 6 do-not-change list |
| DE + EN | 3 |
| Unit + widget tests | 1, 2, 3, 4, 5, 6 |
| `make check` | 7 |
| Not in SettingsService | 1, 4 |
| No SettingsCard wrapper | 5, 6 |
