import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/backup_error_l10n.dart';
import '../l10n/l10n_scope.dart';
import '../models/backup_status.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/media_access_ui.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/backup_status_view.dart';
import '../widgets/home_welcome_header.dart';
import '../widgets/pixelfox_logo.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _onBackupPressed(
    BackupService backup,
    SettingsService settings,
  ) async {
    if (backup.running) return;
    final s = context.l10nRead;

    if (!settings.hasFolders) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.snackPickFoldersFirst)));
      return;
    }

    final allowed = await ensureMediaAccessOrSnack(context, strings: s);
    if (!mounted || !allowed) return;

    await backup.refreshInventory();
    if (!mounted) return;

    // Scan failures (access/path) must not be labeled as "no photos".
    if (backup.status.phase == BackupPhase.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeBackupError(s, backup.status.message))),
      );
      return;
    }

    if (backup.allImages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.snackNoImagesFound)));
      return;
    }

    if (backup.pendingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.storageLow,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(s.snackNothingNew)),
            ],
          ),
        ),
      );
      return;
    }

    final result = await backup.startBackup();
    if (!mounted) return;
    if (result.message != null &&
        result.phase == BackupPhase.failed &&
        result.total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeBackupError(s, result.message))),
      );
    }
  }

  Future<void> _onRefreshPressed(BackupService backup) async {
    // scanInProgress includes quiet auto/resume scans (scanning is UI-only).
    if (backup.running || backup.scanInProgress) return;
    final s = context.l10nRead;
    final allowed = await ensureMediaAccessOrSnack(context, strings: s);
    if (!mounted || !allowed) return;
    await backup.refreshInventory();
  }

  Future<void> _openSettingsThenRefresh(BackupService backup) async {
    // BackupService lives under Home; re-provide it on the settings route so
    // Full Sync (and other maintenance) can call the same instance.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<BackupService>.value(
          value: backup,
          child: const SettingsScreen(),
        ),
      ),
    );
    if (!mounted) return;

    final settings = context.read<SettingsService>();
    final s = context.l10nRead;
    if (settings.hasFolders) {
      final allowed = await ensureMediaAccessOrSnack(context, strings: s);
      if (!mounted || !allowed) return;
    }
    await backup.refreshInventory();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final auth = context.watch<AuthService>();
    final backup = context.watch<BackupService>();
    final settings = context.watch<SettingsService>();
    final status = backup.status;
    final hasPending = backup.pendingCount > 0;
    final allSecured =
        settings.hasFolders &&
        backup.inventoryLoaded &&
        backup.allImages.isNotEmpty &&
        !hasPending &&
        !backup.running;

    return Scaffold(
      appBar: AppBar(
        title: PixelfoxBrandTitle(label: s.homeTitle),
        actions: [
          IconButton(
            tooltip: s.refreshScanTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: backup.running || backup.scanInProgress
                ? null
                : () => _onRefreshPressed(backup),
          ),
          IconButton(
            tooltip: s.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: backup.running
                ? null
                : () => _openSettingsThenRefresh(backup),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (auth.profile != null) ...[
                HomeWelcomeHeader(
                  username: auth.profile!.username,
                  email: auth.profile!.email,
                  pendingCount: backup.pendingCount,
                  securedCount: backup.securedCount,
                  hasFolders: settings.hasFolders,
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: BackupStatusView(
                      status: status,
                      pending: backup.pendingImages,
                      securedCount: backup.securedCount,
                      scanning: backup.scanning,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!settings.hasFolders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    s.tipPickFolders,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: allSecured
                              ? AppTheme.storageLow
                              : AppTheme.foxOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: allSecured
                              ? AppTheme.storageLow.withValues(alpha: 0.85)
                              : null,
                          disabledForegroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: backup.running
                            ? null
                            : () => _onBackupPressed(backup, settings),
                        icon: Icon(
                          backup.running
                              ? Icons.hourglass_top
                              : allSecured
                              ? Icons.verified_outlined
                              : Icons.backup_outlined,
                          size: 26,
                        ),
                        label: Text(
                          backup.running
                              ? s.backingUp
                              : hasPending
                              ? s.secureNewCount(backup.pendingCount)
                              : allSecured
                              ? s.allSecuredButton
                              : s.startBackup,
                        ),
                      ),
                    ),
                  ),
                  if (status.isSuccess || status.phase.name == 'failed') ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: backup.running ? null : backup.resetIdle,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(s.reset),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
