import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/locale_controller.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/backup_ledger.dart';
import 'services/backup_service.dart';
import 'services/gallery_service.dart';
import 'services/media_access.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';
import 'widgets/main_shell.dart';
import 'widgets/pixelfox_logo.dart';

class PixelfoxApp extends StatelessWidget {
  const PixelfoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>();
    final themeMode = context.watch<ThemeModeController>();
    return MaterialApp(
      title: locale.strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode.materialThemeMode,
      themeAnimationDuration: Duration.zero,
      locale: Locale(locale.locale.code),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.initialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelfoxLogo(size: 72),
              const SizedBox(height: 20),
              CircularProgressIndicator(color: AppTheme.foxOrange),
            ],
          ),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    return const _AuthenticatedShell();
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell();

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell>
    with WidgetsBindingObserver {
  BackupService? _backup;
  GalleryService? _gallery;
  bool _booting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_backup != null || _booting) return;
    _booting = true;
    final auth = context.read<AuthService>();
    final settings = context.read<SettingsService>();
    final ledger = context.read<BackupLedger>();
    _backup = BackupService(
      settings: settings,
      ledger: ledger,
      clientProvider: () {
        final client = auth.client;
        if (client == null) {
          throw StateError('Not authenticated');
        }
        return client;
      },
    );
    _gallery = GalleryService(
      clientProvider: () {
        final client = auth.client;
        if (client == null) throw StateError('Not authenticated');
        return client;
      },
    );
    _backup!.startAutoScan();
    // Request runtime photo/storage access before the first scan on mobile.
    // Do not scan when denied — avoids sticky raw exception text on Home.
    unawaited(_bootstrapInventory(auth, settings, ledger));
  }

  Future<void> _bootstrapInventory(
    AuthService auth,
    SettingsService settings,
    BackupLedger ledger,
  ) async {
    await ledger.load(userId: auth.profile?.id);
    if (settings.hasFolders && MediaAccess.isRuntimePermissionRequired) {
      final result = await MediaAccess().ensureReadAccess();
      if (result == MediaAccessResult.denied ||
          result == MediaAccessResult.permanentlyDenied) {
        // Leave idle without a failed status; Home actions show localized snacks.
        return;
      }
    }
    await _backup?.refreshInventory();
  }

  Future<void> _refreshOnResume() async {
    final backup = _backup;
    if (backup == null || !mounted) return;

    // Always re-check media access first (even when inventory is fresh) so a
    // grant in system settings is observed; only the scan itself is throttled.
    final settings = context.read<SettingsService>();
    if (settings.hasFolders && MediaAccess.isRuntimePermissionRequired) {
      final result = await MediaAccess().ensureReadAccess();
      if (result == MediaAccessResult.denied ||
          result == MediaAccessResult.permanentlyDenied) {
        // Skip quiet scan so we do not re-apply a sticky access error.
        // After the user grants access in system settings, ensureReadAccess
        // returns granted and the scan below clears any prior error.
        return;
      }
    }
    // quiet: never show “Looking for photos…” on resume.
    // throttle: skip if we just scanned successfully (failed scans do not
    // arm the throttle — see BackupService._performInventoryScan).
    await backup.refreshInventory(quiet: true, throttle: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backup = _backup;
    if (backup == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // No-op if the timer is already running (avoids notify churn).
        backup.startAutoScan();
        unawaited(_refreshOnResume());
      case AppLifecycleState.inactive:
        // Notification shade / app switcher peek — keep the timer, do not
        // stop/start + rescan (that caused long loading flashes).
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        backup.stopAutoScan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backup?.dispose();
    _gallery?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BackupService>.value(value: _backup!),
        ChangeNotifierProvider<GalleryService>.value(value: _gallery!),
      ],
      child: const MainShell(),
    );
  }
}
