import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../l10n/backup_error_l10n.dart';
import '../l10n/l10n_scope.dart';
import '../models/backup_status.dart';
import '../services/file_scanner.dart';
import '../theme/app_theme.dart';

List<Color> _heroColors(
  BuildContext context,
  List<Color> light,
  List<Color> dark,
) {
  return Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Creative home visual bound to [BackupStatus] phases + pending inventory.
class BackupStatusView extends StatelessWidget {
  const BackupStatusView({
    super.key,
    required this.status,
    this.pending = const [],
    this.securedCount = 0,
    this.scanning = false,
  });

  final BackupStatus status;
  final List<LocalImageFile> pending;
  final int securedCount;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutBack,
      child: KeyedSubtree(
        key: ValueKey(
          '${status.phase}-${pending.length}-$securedCount-$scanning',
        ),
        child: _buildForPhase(context),
      ),
    );
  }

  Widget _buildForPhase(BuildContext context) {
    switch (status.phase) {
      case BackupPhase.working:
        return _WorkingHero(status: status);
      case BackupPhase.success:
        return _SuccessHero(status: status);
      case BackupPhase.failed:
        return _FailedHero(status: status);
      case BackupPhase.idle:
        return _IdleHero(
          pending: pending,
          securedCount: securedCount,
          scanning: scanning,
        );
    }
  }
}

class _IdleHero extends StatelessWidget {
  const _IdleHero({
    required this.pending,
    required this.securedCount,
    required this.scanning,
  });

  final List<LocalImageFile> pending;
  final int securedCount;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    if (scanning) {
      return _HeroCard(
        gradient: AppTheme.heroIdle(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.foxOrange),
            const SizedBox(height: 16),
            Text(
              s.lookingForPhotos,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (pending.isNotEmpty) {
      return _PendingHero(pending: pending, securedCount: securedCount);
    }

    if (securedCount > 0) {
      return _AllSecuredHero(securedCount: securedCount);
    }

    return const _EmptyReadyHero();
  }
}

class _EmptyReadyHero extends StatelessWidget {
  const _EmptyReadyHero();

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return _HeroCard(
      gradient: AppTheme.heroIdle(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.foxOrange.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.foxOrange.withValues(alpha: 0.35),
                width: 3,
              ),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: AppTheme.foxOrange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.readyWhenYouAre,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.readyBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PendingHero extends StatelessWidget {
  const _PendingHero({required this.pending, required this.securedCount});

  final List<LocalImageFile> pending;
  final int securedCount;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final preview = pending.take(8).toList();
    final extra = pending.length - preview.length;

    return _HeroCard(
      gradient: AppTheme.heroPending(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.foxOrange.withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 32,
                  color: AppTheme.foxOrange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending.length == 1
                          ? s.onePhotoNotYetSecured()
                          : s.photosNotYetSecured(pending.length),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (securedCount > 0)
                      Text(
                        s.alreadySafeOnPixelfox(securedCount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.successGreen,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...preview.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: AppTheme.foxAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.notYetSecuredFile(f.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (extra > 0)
            Text(
              s.andMore(extra),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllSecuredHero extends StatelessWidget {
  const _AllSecuredHero({required this.securedCount});

  final int securedCount;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return _HeroCard(
      gradient: _heroColors(
        context,
        const [Color(0xFFD8F3DC), Color(0xFFE8F5E9)],
        const [Color(0xFF1B3A2A), Color(0xFF163028)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 72,
            color: AppTheme.successGreen,
          ),
          const SizedBox(height: 16),
          Text(
            s.everythingSecured,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.successGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.everythingSecuredBody(securedCount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WorkingHero extends StatelessWidget {
  const _WorkingHero({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final label = status.currentFileName ?? '…';
    final progress = status.progress.clamp(0.0, 1.0);
    return _HeroCard(
      gradient: _heroColors(
        context,
        const [Color(0xFFD8E2DC), Color(0xFFE8F1F2)],
        const [Color(0xFF243038), Color(0xFF1C2830)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: status.total > 0 ? progress : null,
                    strokeWidth: 8,
                    color: AppTheme.workingBlue,
                    backgroundColor: AppTheme.workingBlue.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                Icon(
                  Icons.cloud_upload_rounded,
                  size: 56,
                  color: AppTheme.workingBlue.withValues(alpha: 0.95),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.backingUpRightNow,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: AppTheme.workingBlue,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${status.completed + status.failed} / ${status.total}'
            '${status.failed > 0 ? '  ·  ${status.failed}' : ''}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          if (status.total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: AppTheme.foxOrange,
                backgroundColor: AppTheme.foxOrange.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return _HeroCard(
      gradient: _heroColors(
        context,
        const [Color(0xFFD8F3DC), Color(0xFFB7E4C7)],
        const [Color(0xFF1B3A2A), Color(0xFF163028)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF95D5B2), Color(0xFF2D6A4F)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successGreen.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  AppBrand.current.markIcon,
                  size: 72,
                  color: Colors.white70,
                ),
                Positioned(
                  bottom: 28,
                  right: 28,
                  child: Icon(
                    Icons.check_circle,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.allSafeInTheDen,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.successGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.allPhotosSafeMessage(status.completed),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.newPhotosShowAsPending,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FailedHero extends StatelessWidget {
  const _FailedHero({required this.status});

  final BackupStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return _HeroCard(
      gradient: _heroColors(
        context,
        const [Color(0xFFFFE5D9), Color(0xFFFFCAD4)],
        const [Color(0xFF3A2228), Color(0xFF332028)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 88,
            color: Color(0xFF9B2226),
          ),
          const SizedBox(height: 16),
          Text(
            s.almostFailedTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9B2226),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            localizeBackupError(s, status.message),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (status.total > 0) ...[
            const SizedBox(height: 8),
            Text(
              s.uploadSummary(status.completed, status.failed, status.total),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.child, required this.gradient});

  final Widget child;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
