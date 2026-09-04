import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';
import '../theme/app_theme.dart';
import 'gravatar_avatar.dart';

/// Compact welcome strip for the home screen — greeting + name + status vibe.
class HomeWelcomeHeader extends StatelessWidget {
  const HomeWelcomeHeader({
    super.key,
    required this.username,
    required this.email,
    required this.pendingCount,
    required this.securedCount,
    required this.hasFolders,
    this.now,
  });

  final String username;

  /// Account email used for the Gravatar avatar (same as on pixelfox.cc).
  final String email;
  final int pendingCount;
  final int securedCount;
  final bool hasFolders;

  /// Injectable clock for tests; defaults to [DateTime.now].
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final light = theme.brightness == Brightness.light;
    final hour = (now ?? DateTime.now()).hour;
    final greeting = s.greetingForHour(hour);
    final status = s.homeStatusLine(
      pendingCount: pendingCount,
      securedCount: securedCount,
      hasFolders: hasFolders,
    );
    final accent = pendingCount > 0
        ? AppTheme.foxOrange
        : securedCount > 0
        ? AppTheme.storageLow
        : AppTheme.foxAmber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: light ? 0.55 : 0.35),
        ),
        boxShadow: [
          if (light)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Row(
        children: [
          GravatarAvatar(
            email: email,
            size: 52,
            borderColor: scheme.outlineVariant.withValues(alpha: 0.65),
            backgroundColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
