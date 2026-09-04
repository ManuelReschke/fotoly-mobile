import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'pixelfox_logo.dart';

/// Pixelfox cloud storage usage — colors match site `.storage-usage-bar-*`.
class StorageUsageCard extends StatelessWidget {
  const StorageUsageCard({
    super.key,
    required this.profile,
    this.refreshing = false,
    this.onRefresh,
  });

  final UserProfile profile;
  final bool refreshing;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final ratio = profile.storageUsageRatio ?? 0.0;
    final hasData = profile.hasStorageUsage;
    final used = profile.storageUsedBytes ?? 0;
    final quota = profile.storageQuotaBytes ?? 0;
    final remaining =
        profile.storageRemainingBytes ??
        (quota > 0 ? (quota - used).clamp(0, quota) : 0);
    final percent = (ratio * 100).round();

    final barColor = AppTheme.storageBarColor(ratio);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.onSurface.withValues(alpha: 0.04),
                    border: Border.all(
                      color: AppTheme.foxOrange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const PixelfoxLogo(size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.pixelfoxStorage,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      Text(
                        profile.plan.isNotEmpty
                            ? s.planLabel(profile.plan)
                            : s.yourCloudQuota,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: s.refreshUsageTooltip,
                    onPressed: refreshing ? null : onRefresh,
                    icon: refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Text(
                s.storageUnavailable,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatBytes(used),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 4),
                    child: Text(
                      s.ofQuota(formatBytes(quota)),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return SizedBox(
                      height: 10,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: scheme.onSurface.withValues(alpha: 0.08),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value.clamp(0.0, 1.0),
                            child: ColoredBox(color: barColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile.imageCount != null
                        ? s.imagesCount(profile.imageCount!)
                        : s.imagesOnPixelfox,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    s.freeSpace(formatBytes(remaining)),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.storageLow,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
