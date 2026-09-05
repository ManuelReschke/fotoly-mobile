import 'package:flutter/material.dart';

/// Color tokens for one white-label pack.
class BrandPalette {
  const BrandPalette({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.accent,
    required this.navbar,
    required this.lightSurface,
    required this.darkSurface,
    required this.darkCard,
    required this.working,
    required this.heroIdleLight,
    required this.heroIdleDark,
    required this.heroPendingLight,
    required this.heroPendingDark,
  });

  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color accent;
  final Color navbar;
  final Color lightSurface;
  final Color darkSurface;
  final Color darkCard;
  final Color working;
  final List<Color> heroIdleLight;
  final List<Color> heroIdleDark;
  final List<Color> heroPendingLight;
  final List<Color> heroPendingDark;
}

/// Compile-time white-label pack (PixelFox vs Fotoly).
///
/// Selected via `--dart-define=FLAVOR=fotoly` and/or `--flavor fotoly`.
/// Storage keys stay pack-prefixed so both apps can sit on one device.
class AppBrand {
  const AppBrand({
    required this.id,
    required this.displayName,
    required this.websiteHost,
    required this.apiBaseUrl,
    required this.callbackUrlScheme,
    required this.androidApplicationId,
    required this.logoAsset,
    required this.logoMarkAsset,
    required this.appIconAsset,
    required this.markIcon,
    required this.palette,
  });

  final String id;
  final String displayName;
  final String websiteHost;
  final String apiBaseUrl;
  final String callbackUrlScheme;
  final String androidApplicationId;
  final String logoAsset;
  final String logoMarkAsset;
  final String appIconAsset;
  final IconData markIcon;
  final BrandPalette palette;

  String get appRedirectUri => '$callbackUrlScheme://auth/callback';

  /// Login wordmark, e.g. `FOTOLY.EU` / `PIXELFOX.CC`.
  String get wordmark => websiteHost.toUpperCase();

  String get apiKeyStorageKey => '${id}_api_key';
  String get accessTokenStorageKey => '${id}_access_token';
  String get selectedFoldersKey => '${id}_selected_folders';
  String get backupLedgerKey => '${id}_backup_ledger_v1';
  String get localePrefsKey => '${id}_locale';
  String get themeModePrefsKey => '${id}_theme_mode';

  static const pixelfox = AppBrand(
    id: 'pixelfox',
    displayName: 'Pixelfox',
    websiteHost: 'pixelfox.cc',
    apiBaseUrl: 'https://pixelfox.cc',
    callbackUrlScheme: 'pixelfox',
    androidApplicationId: 'cc.pixelfox.pixelfox_mobile',
    logoAsset: 'assets/brand/pixelfox-logo.png',
    logoMarkAsset: 'assets/brand/pixelfox-logo-32.png',
    appIconAsset: 'assets/brand/app_icon.png',
    markIcon: Icons.pets,
    palette: BrandPalette(
      primary: Color(0xFFF97316),
      primaryDark: Color(0xFFF97316),
      secondary: Color(0xFFF59E0B),
      accent: Color(0xFFF59E0B),
      navbar: Color(0xFF1A1423),
      lightSurface: Color(0xFFFFF8F0),
      darkSurface: Color(0xFF1A1423),
      darkCard: Color(0xFF241C2E),
      working: Color(0xFF3D5A80),
      heroIdleLight: [Color(0xFFFFE8D6), Color(0xFFFFF8F0)],
      heroIdleDark: [Color(0xFF3A2A28), Color(0xFF2A1F24)],
      heroPendingLight: [Color(0xFFFFE8D6), Color(0xFFFFF3E0)],
      heroPendingDark: [Color(0xFF3D2C22), Color(0xFF33261C)],
    ),
  );

  static const fotoly = AppBrand(
    id: 'fotoly',
    displayName: 'Fotoly',
    websiteHost: 'fotoly.eu',
    apiBaseUrl: 'https://fotoly.eu',
    callbackUrlScheme: 'fotoly',
    androidApplicationId: 'eu.fotoly.fotoly_mobile',
    logoAsset: 'assets/brand/fotoly-logo.png',
    logoMarkAsset: 'assets/brand/fotoly-logo-32.png',
    appIconAsset: 'assets/brand/fotoly-app-icon.png',
    markIcon: Icons.camera,
    palette: BrandPalette(
      // Website Schiefer preset (internal/pkg/theme + daisyui slate).
      primary: Color(0xFF334155),
      primaryDark: Color(0xFF64748B),
      secondary: Color(0xFF1E293B),
      accent: Color(0xFF38BDF8),
      navbar: Color(0xFF0F172A),
      lightSurface: Color(0xFFF8FAFC),
      darkSurface: Color(0xFF0F172A),
      darkCard: Color(0xFF0B1220),
      working: Color(0xFF334155),
      heroIdleLight: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
      heroIdleDark: [Color(0xFF1E293B), Color(0xFF0F172A)],
      heroPendingLight: [Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
      heroPendingDark: [Color(0xFF1E293B), Color(0xFF0B1220)],
    ),
  );

  static const List<AppBrand> known = [pixelfox, fotoly];

  static AppBrand? _override;

  static AppBrand get current => _override ?? fromEnvironment();

  static AppBrand fromId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final brand in known) {
      if (brand.id == normalized) return brand;
    }
    throw ArgumentError.value(id, 'id', 'Unknown app flavor');
  }

  static AppBrand fromEnvironment() {
    const flavor = String.fromEnvironment('FLAVOR');
    const flutterFlavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');
    final raw = flavor.isNotEmpty ? flavor : flutterFlavor;
    if (raw.isEmpty) return fotoly;
    return fromId(raw);
  }

  @visibleForTesting
  static void debugOverride(AppBrand? brand) => _override = brand;

  @visibleForTesting
  static void debugReset() => _override = null;
}
