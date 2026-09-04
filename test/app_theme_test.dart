import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/config/app_brand.dart';
import 'package:pixelfox_mobile/theme/app_theme.dart';

void main() {
  tearDown(AppBrand.debugReset);

  test('light and dark themes have opposite brightness and distinct cards', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.surface, AppTheme.softCream);
    expect(dark.colorScheme.surface, AppTheme.deepNight);
    expect(light.cardTheme.color, Colors.white);
    expect(dark.cardTheme.color, const Color(0xFF0B1220));
    expect(light.inputDecorationTheme.fillColor, Colors.white);
    expect(dark.inputDecorationTheme.fillColor, const Color(0xFF0B1220));
    expect(light.colorScheme.primary, const Color(0xFF334155));
  });

  test('fotoly palette matches website Schiefer tokens', () {
    final palette = AppBrand.fotoly.palette;
    expect(palette.primary, const Color(0xFF334155));
    expect(palette.primaryDark, const Color(0xFF64748B));
    expect(palette.secondary, const Color(0xFF1E293B));
    expect(palette.accent, const Color(0xFF38BDF8));
    expect(palette.navbar, const Color(0xFF0F172A));
    expect(palette.lightSurface, const Color(0xFFF8FAFC));
    expect(palette.darkSurface, const Color(0xFF0F172A));
    expect(palette.darkCard, const Color(0xFF0B1220));
  });

  test('pixelfox ThemeData stays fox orange when overridden', () {
    AppBrand.debugOverride(AppBrand.pixelfox);

    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(AppTheme.foxOrange, const Color(0xFFF97316));
    expect(light.colorScheme.primary, const Color(0xFFF97316));
    expect(dark.colorScheme.surface, const Color(0xFF1A1423));
    expect(dark.cardTheme.color, const Color(0xFF241C2E));
  });

  test('fotoly ThemeData uses Schiefer primary, navbar and accent', () {

    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(AppTheme.foxOrange, const Color(0xFF334155));
    expect(AppTheme.deepNight, const Color(0xFF0F172A));
    expect(AppTheme.softCream, const Color(0xFFF8FAFC));
    expect(light.colorScheme.primary, const Color(0xFF334155));
    expect(light.colorScheme.secondary, const Color(0xFF38BDF8));
    expect(light.colorScheme.surface, const Color(0xFFF8FAFC));
    expect(light.appBarTheme.backgroundColor, const Color(0xFF0F172A));
    expect(
      light.filledButtonTheme.style?.backgroundColor?.resolve({}),
      const Color(0xFF334155),
    );
    expect(dark.colorScheme.primary, const Color(0xFF64748B));
    expect(dark.colorScheme.surface, const Color(0xFF0F172A));
    expect(dark.cardTheme.color, const Color(0xFF0B1220));
    expect(dark.appBarTheme.backgroundColor, const Color(0xFF0F172A));
  });
}
