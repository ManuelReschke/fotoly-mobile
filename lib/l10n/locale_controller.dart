import 'package:flutter/foundation.dart';

import '../config/app_brand.dart';
import '../services/storage.dart';
import 'app_strings.dart';
import 'app_strings_de.dart';
import 'app_strings_en.dart';

String get kLocalePrefsKey => AppBrand.current.localePrefsKey;

/// Supported app languages. Default is German.
enum AppLocale {
  de,
  en;

  String get code => name;

  static AppLocale fromCode(String? code) {
    switch (code) {
      case 'en':
        return AppLocale.en;
      case 'de':
      default:
        return AppLocale.de;
    }
  }

  AppStrings get strings {
    switch (this) {
      case AppLocale.de:
        return const AppStringsDe();
      case AppLocale.en:
        return const AppStringsEn();
    }
  }
}

/// Persists and broadcasts the active [AppLocale].
class LocaleController extends ChangeNotifier {
  LocaleController({required this._prefs});

  final PrefsStore _prefs;
  AppLocale _locale = AppLocale.de;

  AppLocale get locale => _locale;
  AppStrings get strings => _locale.strings;

  /// All locales offered in Settings (order = picker order).
  static const List<AppLocale> supported = [AppLocale.de, AppLocale.en];

  Future<void> load() async {
    final raw = await _prefs.getString(kLocalePrefsKey);
    _locale = AppLocale.fromCode(raw);
    notifyListeners();
  }

  Future<void> setLocale(AppLocale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _prefs.setString(kLocalePrefsKey, locale.code);
    notifyListeners();
  }
}
