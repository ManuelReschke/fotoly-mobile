import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_scope.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_theme.dart';

/// Rounded settings card for DE / EN language selection.
class LanguageCard extends StatelessWidget {
  const LanguageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final controller = context.watch<LocaleController>();
    final current = controller.locale;
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
                    Icons.language,
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
                        s.languageSectionTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      Text(
                        s.languageSectionSubtitle,
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
            ...LocaleController.supported.map((locale) {
              final selected = locale == current;
              final label = locale.strings.languageName;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? AppTheme.foxOrange.withValues(alpha: 0.10)
                      : scheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => controller.setLocale(locale),
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
                          Text(
                            locale == AppLocale.de ? '🇩🇪' : '🇬🇧',
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
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
