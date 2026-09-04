import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n_scope.dart';
import '../models/full_sync_result.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';

/// Settings card: Full Sync with double confirmation.
class FullSyncCard extends StatelessWidget {
  const FullSyncCard({super.key});

  Future<void> _runFullSync(BuildContext context) async {
    final s = context.l10nRead;
    final backup = context.read<BackupService>();

    if (backup.running || backup.fullSyncRunning) {
      _snack(context, s.fullSyncBusyBackup);
      return;
    }

    final continueFirst = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.fullSyncConfirm1Title),
        content: SingleChildScrollView(child: Text(s.fullSyncConfirm1Body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.fullSyncCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.fullSyncConfirm1Continue),
          ),
        ],
      ),
    );
    if (continueFirst != true || !context.mounted) return;

    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.fullSyncConfirm2Title),
        content: Text(s.fullSyncConfirm2Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.fullSyncCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.fullSyncConfirm2Start),
          ),
        ],
      ),
    );
    if (start != true || !context.mounted) return;

    // Non-dismissible progress while work runs.
    // Dialog routes are siblings of the Settings route, so they do not see
    // Provider<BackupService> — listen to the instance we already hold.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: ListenableBuilder(
            listenable: backup,
            builder: (context, _) {
              return AlertDialog(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        backup.fullSyncTotal > 0
                            ? s.fullSyncProgress(
                                backup.fullSyncChecked,
                                backup.fullSyncTotal,
                              )
                            : s.fullSyncTitle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    FullSyncResult result;
    try {
      result = await backup.fullSyncRemote();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _snack(context, '$e');
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    _showResultSnack(context, s, result);
  }

  void _showResultSnack(BuildContext context, AppStrings s, FullSyncResult r) {
    if (r.busy) {
      _snack(context, s.fullSyncBusyBackup);
      return;
    }
    if (r.abortedAuth) {
      _snack(context, s.fullSyncAuthFailed);
      return;
    }
    if (r.checked == 0 && r.removed == 0 && r.skippedNoUuid == 0) {
      _snack(context, s.fullSyncNothingToCheck);
      return;
    }
    if (r.checked == 0 && r.skippedNoUuid > 0) {
      _snack(context, s.fullSyncNothingToCheck);
      return;
    }
    _snack(
      context,
      s.fullSyncResultSnack(
        checked: r.checked,
        removed: r.removed,
        skippedNoUuid: r.skippedNoUuid,
        errors: r.errors,
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final backup = context.watch<BackupService>();
    final busy = backup.running || backup.fullSyncRunning;
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
                    color: AppTheme.foxOrange.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.sync,
                    color: AppTheme.foxOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.fullSyncTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      Text(
                        s.fullSyncSubtitle,
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
            OutlinedButton.icon(
              onPressed: busy ? null : () => _runFullSync(context),
              icon: const Icon(Icons.cloud_sync_outlined),
              label: Text(s.fullSyncButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurface.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
