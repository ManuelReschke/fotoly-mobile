# Theme Mode (Hell / Dark / System) — Design Spec

**Date:** 2026-08-13  
**Status:** Approved for planning  
**App:** fotoly_mobile (Flutter)

## Problem

The app is always light. `MaterialApp` uses only `AppTheme.light()` and never sets `themeMode` or `darkTheme`. Many settings cards and screens hardcode `Colors.white` and `AppTheme.deepNight`, so a naive theme switch would leave surfaces cream/white in Dark.

Users need a Settings control for **Hell**, **Dark**, or **System**, with a real dark look across the app.

## Goals

- Add an appearance picker in **Settings**: Hell / Dark / System.
- Persist the choice locally (same Prefs store as locale).
- Default preference: **system**. Invalid stored value: **light**. Unspecified OS brightness: Flutter’s light fallback.
- Provide `AppTheme.dark()` and wire `MaterialApp.theme` / `darkTheme` / `themeMode`.
- Restyle visible cards and screens so Dark is coherent (surfaces and text follow `ColorScheme`).
- DE + EN copy via existing `lib/l10n/`.
- Unit- and widget-testable without a real device theme dance beyond Flutter `ThemeMode`.

## Non-goals

- A shared `SettingsCard` super-widget (cards stay independent).
- Per-screen theme overrides or scheduled auto-switch.
- Redesigning brand colors, storage-bar thresholds, or the home header gradient.
- Animating theme transitions.
- Dynamic color / Material You wallpaper palettes.
- Changing backup, auth, or folder behavior.

## Product decisions (locked)

| Topic | Decision |
|-------|----------|
| Options | Hell, Dark, System |
| Default (missing prefs key) | `system` |
| Invalid prefs string | `light` |
| System with unknown OS brightness | Flutter uses light |
| Placement | Settings, card **above** `LanguageCard` |
| Control | Three tappable rows, same pattern as language |
| Feedback on change | Immediate rebuild, no snackbar / dialog |
| Scope of dark look | Login, Home, Settings cards, album sheet |
| Brand colors | Fox orange, storage traffic-light, AppBar `deepNight` stay |

## Architecture

```
main.dart
  load ThemeModeController  (prefs)
  MultiProvider → PixelfoxApp

PixelfoxApp
  watch ThemeModeController
  MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: controller.materialThemeMode,
  )

Settings
  AppearanceCard
    tap Hell | Dark | System
    → ThemeModeController.setPreference(...)
    → prefs write + notifyListeners
```

Keep this **out of** `SettingsService`. Locale already lives in its own controller; appearance follows that split. Folder persistence stays unrelated.

### Components

#### 1. `AppThemePreference` + `ThemeModeController`

New file: `lib/theme/theme_mode_controller.dart`.

```dart
enum AppThemePreference { system, light, dark }
```

- `code` → `'system' | 'light' | 'dark'`
- `fromCode(String? code)`:
  - `null` / missing → `system` (first launch default)
  - `'light'` → `light`
  - `'dark'` → `dark`
  - `'system'` → `system`
  - anything else → `light` (explicit fallback)
- `ThemeMode get materialThemeMode` maps 1:1 onto Flutter’s `ThemeMode`.

`ThemeModeController` mirrors `LocaleController`:

- constructed with `PrefsStore`
- `load()` reads `kThemeModePrefsKey` (`pixelfox_theme_mode`)
- `setPreference(AppThemePreference)` no-ops if unchanged; otherwise updates memory, writes prefs, `notifyListeners()`
- `static const supported` order for the picker: **light, dark, system** (Hell, Dark, System)

In-memory default before `load()` is `system`. If prefs write fails, the in-memory value stays; next cold start reloads from prefs (or default/fallback).

#### 2. `AppTheme.dark()`

Extend `lib/theme/app_theme.dart`. Do not remove `light()`.

Dark theme:

- `ColorScheme.fromSeed` with the same fox orange / amber / error seed, `brightness: Brightness.dark`
- Scaffold and surfaces use a dark night tone (existing `deepNight` or a seed-derived dark surface — must be clearly dark, not cream)
- AppBar stays `deepNight` + white foreground (same as light)
- Filled buttons stay fox orange + white label
- Input fill uses a dark surface, not white

Light theme keeps today’s cream / white inputs. Shared brand constants stay on `AppTheme`.

#### 3. `PixelfoxApp` + `main.dart`

- Create and `load()` `ThemeModeController` in the same `Future.wait` as auth / settings / locale / ledger.
- Provide it via `ChangeNotifierProvider`.
- `PixelfoxApp` watches the controller and sets `theme`, `darkTheme`, `themeMode`.
- Login (unauthenticated) uses the same `MaterialApp`, so the preference applies before and after auth.

#### 4. `AppearanceCard`

New widget: `lib/widgets/appearance_card.dart`.

Visual structure matches `LanguageCard`:

- Card chrome (will use theme surface, not hardcoded white)
- Icon tile + title + subtitle from l10n
- Three rows: Hell, Dark, System
- Selected row: orange-tinted fill, check icon
- Icons (not flags): e.g. `light_mode`, `dark_mode`, `brightness_auto`

Insert in `SettingsScreen` **above** `LanguageCard`.

#### 5. Color migration (thorough, not a new card framework)

Replace hardcoded light-only surfaces/text with `Theme.of(context).colorScheme`:

| Token | Use |
|-------|-----|
| `colorScheme.surface` | Card backgrounds |
| `colorScheme.onSurface` | Primary labels |
| `colorScheme.onSurface` at ~0.55–0.75 alpha | Subtitles / muted |
| `colorScheme.outline` / low-alpha `onSurface` | Hairline borders, unselected row chrome |

**In scope:**

- Settings: profile card, logout button chrome, `StorageUsageCard`, `FoldersBackupCard`, `LanguageCard`, `FullSyncCard`, new `AppearanceCard`
- `login_screen.dart`
- `backup_status_view.dart` (hero copy that currently forces `deepNight`)
- `album_picker_sheet.dart` (sheet background + tiles)

**Stay hardcoded (by design):**

- Fox orange / amber / storage traffic-light
- AppBar `deepNight` + white title
- White foreground on orange filled buttons
- `home_welcome_header.dart` white text on the night gradient
- Logo default white (used on dark/brand backgrounds)

Do not extract a shared settings card wrapper in this change.

#### 6. l10n

Add to `AppStrings` + DE + EN (no hardcoded English-only UI):

- section title (e.g. Erscheinungsbild / Appearance)
- section subtitle
- Hell / Light
- Dark / Dark
- System / System

Picker order is independent of locale. Labels come from the active `AppStrings`.

## Data flow

1. Cold start: `load()` → missing key = system; garbage = light.
2. User taps a row → `setPreference` → prefs + notify → `MaterialApp` rebuilds with new `themeMode`.
3. `ThemeMode.system` follows `MediaQuery.platformBrightnessOf`; Flutter already treats unspecified brightness as light.

No extra dialog. No restart.

## Error handling

| Situation | Behavior |
|-----------|----------|
| Missing prefs key | `system` |
| Unknown prefs string | `light` |
| Prefs write failure | Keep in-memory preference; next start reloads disk |
| OS brightness unspecified | Light (Flutter) |

Theme never blocks login or backup.

## Testing

**Unit** (`test/theme_mode_controller_test.dart`, `MemoryPrefsStore`):

- `fromCode(null)` → system
- `fromCode('light'|'dark'|'system')` round-trip
- `fromCode('nope')` → light
- `load()` with empty prefs → system
- `setPreference(dark)` persists `'dark'` and survives a new controller `load()`
- unchanged `setPreference` does not rewrite unnecessarily (same as locale early-return)

**Widget:**

- `AppearanceCard` shows the three localized labels
- selected preference shows the check
- tap Dark updates the controller
- tests that pump `AppearanceCard` or `PixelfoxApp` provide a `ThemeModeController`
- existing `pumpL10n` helpers for isolated status widgets stay unchanged unless they start reading the controller

**Theme smoke:** `AppTheme.dark().brightness == Brightness.dark` and `AppTheme.light().brightness == Brightness.light`.

No real device / Chrome visual QA required for unit tests. Manual check: Settings → switch all three modes; confirm Login and Home follow.

## Files (expected)

| Path | Change |
|------|--------|
| `lib/theme/theme_mode_controller.dart` | new |
| `lib/theme/app_theme.dart` | add `dark()` |
| `lib/widgets/appearance_card.dart` | new |
| `lib/main.dart` | construct, load, provide controller |
| `lib/app.dart` | `darkTheme` + `themeMode` |
| `lib/screens/settings_screen.dart` | insert card |
| `lib/l10n/app_strings.dart` + `_de` + `_en` | strings |
| Settings / login / status / album / language / storage / folders / full-sync widgets | ColorScheme |
| `test/theme_mode_controller_test.dart` | new |
| `test/widget_test.dart` (and helpers) | provider + appearance coverage |

## Success criteria

- Settings offers Hell / Dark / System.
- Fresh install follows the OS; garbage prefs become light.
- Changing the option updates the whole app immediately, including Login after logout.
- Dark mode does not leave white settings cards or unreadable `deepNight` text on dark scaffolds.
- `make check` passes.
