import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../services/storage.dart';

String get kThemeModePrefsKey => AppBrand.current.themeModePrefsKey;

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
  ThemeModeController({required this._prefs});

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
