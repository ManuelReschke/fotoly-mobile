import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n_scope.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_controller.dart';

/// Rounded settings card for Hell / Dark / System appearance.
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final controller = context.watch<ThemeModeController>();
    final current = controller.preference;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.workingBlue.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.brightness_6,
                    color: AppTheme.workingBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.appearanceSectionTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      Text(
                        s.appearanceSectionSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...ThemeModeController.supported.map((mode) {
              final selected = mode == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? AppTheme.foxOrange.withValues(alpha: 0.10)
                      : scheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => controller.setPreference(mode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppTheme.foxOrange.withValues(alpha: 0.45)
                              : scheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_icon(mode), color: scheme.onSurface, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _label(s, mode),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: scheme.onSurface,
                                  ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.foxOrange,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

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
