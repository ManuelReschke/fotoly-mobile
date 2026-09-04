import 'package:flutter/material.dart';

import '../config/app_brand.dart';

/// Brand tokens aligned with the active white-label pack.
class AppTheme {
  static BrandPalette get _palette => AppBrand.current.palette;

  /// Brand primary (PixelFox orange / Fotoly Schiefer slate).
  static Color get foxOrange => _palette.primary;
  static Color get foxAmber => _palette.accent;
  static const Color foxRed = Color(0xFFEF4444); // red-500

  /// Official site storage bar colors from styles.css:
  /// `.storage-usage-bar-low|medium|high`
  static const Color storageLow = Color(0xFF10B981); // emerald-500
  static const Color storageMedium = Color(0xFFF59E0B); // amber-500
  static const Color storageHigh = Color(0xFFEF4444); // red-500

  /// Site top page-load progress gradient stops.
  static const Color progressGreen = Color(0xFF22C55E);
  static const Color progressBlue = Color(0xFF0EA5E9);
  static const Color progressOrange = Color(0xFFF97316);

  static Color get deepNight => _palette.navbar;
  static Color get softCream => _palette.lightSurface;
  static const Color successGreen = storageLow;
  static Color get workingBlue => _palette.working;

  /// Asset paths for the active brand mark.
  static String get logoAsset => AppBrand.current.logoAsset;
  static String get logoMarkAsset => AppBrand.current.logoMarkAsset;

  /// Pick storage bar color like the website (low / medium / high).
  /// Thresholds: &lt;70% low, &lt;90% medium, else high.
  static Color storageBarColor(double ratio) {
    if (ratio >= 0.9) return storageHigh;
    if (ratio >= 0.7) return storageMedium;
    return storageLow;
  }

  static Color get darkCard => _palette.darkCard;

  static List<Color> heroIdle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _palette.heroIdleDark
        : _palette.heroIdleLight;
  }

  static List<Color> heroPending(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _palette.heroPendingDark
        : _palette.heroPendingLight;
  }

  static ThemeData light() {
    final palette = _palette;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.light,
      primary: palette.primary,
      secondary: palette.accent,
      error: storageHigh,
      surface: palette.lightSurface,
    ).copyWith(surfaceContainerLowest: Colors.white);
    return _base(
      scheme: scheme,
      scaffold: palette.lightSurface,
      card: Colors.white,
      palette: palette,
    );
  }

  static ThemeData dark() {
    final palette = _palette;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primaryDark,
      brightness: Brightness.dark,
      primary: palette.primaryDark,
      secondary: palette.accent,
      error: storageHigh,
      surface: palette.darkSurface,
    ).copyWith(surfaceContainerLowest: palette.darkCard);
    return _base(
      scheme: scheme,
      scaffold: palette.darkSurface,
      card: palette.darkCard,
      palette: palette,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required BrandPalette palette,
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
          side: BorderSide(color: palette.primary.withValues(alpha: 0.15)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.navbar,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
