import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/backup_error_l10n.dart';
import '../l10n/l10n_scope.dart';
import '../models/backup_status.dart';
import '../models/upload_size_policy.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/camera_folder.dart';
import '../services/media_access_ui.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/backup_status_view.dart';
import '../widgets/home_welcome_header.dart';
import '../widgets/pixelfox_logo.dart';
import '../widgets/premium_upsell_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _addingCameraFolder = false;

  Future<void> _addStandardCameraFolder(BackupService backup) async {
    if (_addingCameraFolder || backup.running) return;
    final s = context.l10nRead;
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.folderPickerUnavailable)));
      return;
    }

    setState(() => _addingCameraFolder = true);
    try {
      final allowed = await ensureMediaAccessOrSnack(context, strings: s);
      if (!mounted || !allowed) return;

      final path = locateStandardCameraFolder();
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.cameraFolderNotFound)));
        return;
      }

      await context.read<SettingsService>().addFolder(path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.addedFolder(path))));
      await backup.refreshInventory();
    } finally {
      if (mounted) setState(() => _addingCameraFolder = false);
    }
  }

  Future<void> _onBackupPressed(
    BackupService backup,
    SettingsService settings,
  ) async {
    if (backup.running) return;
    final s = context.l10nRead;

    if (context.read<AuthService>().isOffline) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.offlineBackupBlocked)));
      return;
    }

    if (!settings.hasFolders) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.snackPickFoldersFirst)));
      return;
    }

    final allowed = await ensureMediaAccessOrSnack(context, strings: s);
    if (!mounted || !allowed) return;

    final result = await backup.startBackup();
    if (!mounted) return;
    if (result.phase == BackupPhase.failed && result.total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeBackupError(s, result.message))),
      );
      return;
    }

    if (result.isIdle &&
        backup.hasImages &&
        backup.pendingCount == 0 &&
        backup.tooLargeCount == 0) {
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
    }
  }

  Future<void> _onRefreshPressed(BackupService backup) async {
    if (backup.running || backup.scanning) return;
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
    final backup = context.read<BackupService>();
    final controls = context.select((BackupService service) {
      final running = service.running;
      final pending = running ? 0 : service.pendingCount;
      final tooLarge = running ? 0 : service.tooLargeCount;
      return (
        running: running,
        scanning: service.scanning,
        phase: service.status.phase,
        pending: pending,
        tooLarge: tooLarge,
        plan: pending == 0 && tooLarge > 0 ? service.oversizedUploadPlan : null,
        hasInventory: service.inventoryLoaded && service.hasImages,
      );
    });
    final settings = context.watch<SettingsService>();
    final hasPending = controls.pending > 0;
    final unlockPlan = !hasPending && controls.plan != null;
    final blockedOnly =
        !hasPending && controls.tooLarge > 0 && controls.plan == null;
    final allSecured =
        settings.hasFolders &&
        controls.hasInventory &&
        !hasPending &&
        controls.tooLarge == 0 &&
        !controls.running;
    final actionLabel = controls.running
        ? s.backingUp
        : hasPending
        ? s.secureNewCount(controls.pending)
        : unlockPlan
        ? (controls.plan == HigherUploadPlan.premiumMax
              ? s.premiumMaxUpsellCta
              : s.premiumUpsellCta)
        : blockedOnly
        ? s.tooLargeForEveryPlanButton
        : allSecured
        ? s.allSecuredButton
        : s.startBackup;

    return Scaffold(
      appBar: AppBar(
        title: PixelfoxBrandTitle(label: s.homeTitle),
        actions: [
          IconButton(
            tooltip: s.refreshScanTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: controls.running || controls.scanning
                ? null
                : () => _onRefreshPressed(backup),
          ),
          IconButton(
            tooltip: s.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: controls.running
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
                Selector<
                  BackupService,
                  ({int pending, int secured, int oversized})
                >(
                  selector: (_, service) => (
                    pending: service.pendingCount,
                    secured: service.securedCount,
                    oversized: service.tooLargeCount,
                  ),
                  builder: (context, counts, _) => HomeWelcomeHeader(
                    username: auth.profile!.username,
                    email: auth.profile!.email,
                    pendingCount: counts.pending,
                    securedCount: counts.secured,
                    hasFolders: settings.hasFolders,
                    oversizedCount: counts.oversized,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Consumer<BackupService>(
                  builder: (context, backup, _) => LayoutBuilder(
                    builder: (context, constraints) {
                      final status = backup.status;
                      final statusView = BackupStatusView(
                        status: status,
                        pending: status.isIdle
                            ? backup.pendingImages
                            : const [],
                        tooLarge: status.isWorking
                            ? const []
                            : backup.tooLargeImages,
                        maxUploadBytes: auth.profile?.maxUploadBytes,
                        onUnlockPlan: () => launchPricingPage(context),
                        securedCount: status.isWorking
                            ? 0
                            : backup.securedCount,
                        scanning: backup.scanning,
                        onSecureCamera: !settings.hasFolders && !backup.running
                            ? () => _addStandardCameraFolder(backup)
                            : null,
                        securingCamera: _addingCameraFolder,
                        onChooseFolders: !settings.hasFolders && !backup.running
                            ? () => _openSettingsThenRefresh(backup)
                            : null,
                      );
                      // Pending photos scroll inside the card. This branch stays
                      // out of the page scroll view so the start page does not grow.
                      final pendingOverview =
                          status.phase == BackupPhase.idle &&
                          !backup.scanning &&
                          backup.pendingCount > 0;
                      if (pendingOverview) return statusView;
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(child: statusView),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (settings.hasFolders) ...[
                const SizedBox(height: 16),
                // Plan labels such as "Premium freischalten" wrap beside
                // Reset. A fixed height clips the second line.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
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
                            minimumSize: const Size(0, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 17,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: controls.running || blockedOnly
                              ? null
                              : unlockPlan
                              ? () => launchPricingPage(context)
                              : () => _onBackupPressed(backup, settings),
                          icon: Icon(
                            controls.running
                                ? Icons.hourglass_top
                                : unlockPlan
                                ? Icons.workspace_premium_outlined
                                : allSecured
                                ? Icons.verified_outlined
                                : Icons.backup_outlined,
                            size: 26,
                          ),
                          label: Text(actionLabel, textAlign: TextAlign.center),
                        ),
                      ),
                      if (controls.phase == BackupPhase.success ||
                          controls.phase == BackupPhase.failed) ...[
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: controls.running ? null : backup.resetIdle,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(s.reset),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
