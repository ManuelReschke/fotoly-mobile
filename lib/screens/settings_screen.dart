import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_info.dart';
import '../l10n/l10n_scope.dart';
import '../models/backup_folder.dart';
import '../models/pixelfox_album.dart';
import '../services/auth_service.dart';
import '../services/media_access_ui.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_picker_sheet.dart';
import '../widgets/appearance_card.dart';
import '../widgets/folders_backup_card.dart';
import '../widgets/full_sync_card.dart';
import '../widgets/gravatar_avatar.dart';
import '../widgets/language_card.dart';
import '../widgets/pixelfox_logo.dart';
import '../widgets/storage_usage_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _manualController = TextEditingController();
  bool _picking = false;
  bool _refreshingProfile = false;

  bool get _folderPickerSupported => !kIsWeb;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile(silent: true);
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile({bool silent = false}) async {
    if (_refreshingProfile) return;
    setState(() => _refreshingProfile = true);
    final ok = await context.read<AuthService>().refreshProfile();
    if (!mounted) return;
    setState(() => _refreshingProfile = false);
    if (!silent && !ok) {
      _snack(context.l10nRead.couldNotRefreshStorage);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<List<PixelfoxAlbum>> _loadAlbums() async {
    final client = context.read<AuthService>().client;
    if (client == null) return [];
    return client.listAlbums();
  }

  /// Pick album mapping after a path is known, then persist the folder.
  Future<void> _finishAddFolder(String path) async {
    final s = context.l10nRead;
    final pick = await showAlbumPickerSheet(
      context: context,
      loadAlbums: _loadAlbums,
      folderPath: path,
    );
    if (!mounted || pick == null) return;

    await context.read<SettingsService>().addFolder(
      path,
      albumId: pick.albumId,
      albumTitle: pick.albumTitle,
    );
    if (!mounted) return;
    final albumPart = pick.albumTitle != null ? ' → ${pick.albumTitle}' : '';
    _snack('${s.addedFolder(path)}$albumPart');
  }

  Future<void> _changeAlbum(BackupFolder folder) async {
    final pick = await showAlbumPickerSheet(
      context: context,
      loadAlbums: _loadAlbums,
      folderPath: folder.path,
      selectedAlbumId: folder.albumId,
    );
    if (!mounted || pick == null) return;
    await context.read<SettingsService>().updateFolderAlbum(
      folder.path,
      albumId: pick.albumId,
      albumTitle: pick.albumTitle,
    );
  }

  Future<void> _pickFolder() async {
    final s = context.l10nRead;
    if (!_folderPickerSupported) {
      _snack(s.folderPickerUnavailable);
      return;
    }

    final ok = await ensureMediaAccessOrSnack(context, strings: s);
    if (!mounted || !ok) return;

    setState(() => _picking = true);
    try {
      // file_picker ≥11: static API (platform instance API removed).
      final path = await FilePicker.getDirectoryPath(dialogTitle: s.pickFolder);
      if (!mounted) return;
      if (path == null) {
        _snack(s.noFolderSelected);
        return;
      }
      await _finishAddFolder(path);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addManual() async {
    final s = context.l10nRead;
    final path = _manualController.text.trim();
    if (path.isEmpty) return;

    if (!kIsWeb) {
      final ok = await ensureMediaAccessOrSnack(context, strings: s);
      if (!mounted || !ok) return;
    }

    _manualController.clear();
    if (kIsWeb) {
      // Still allow mapping on web for UI testing.
      await _finishAddFolder(path);
      if (mounted) _snack(s.pathSavedUiOnly);
      return;
    }
    await _finishAddFolder(path);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();
    final profile = auth.profile;
    // System nav / gesture bar — keep logout + footer above it.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.45);

    return Scaffold(
      appBar: AppBar(title: PixelfoxBrandTitle(label: s.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
        children: [
          if (profile != null) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: GravatarAvatar(
                  email: profile.email,
                  size: 48,
                  borderColor: AppTheme.foxOrange.withValues(alpha: 0.2),
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
                ),
                title: Text(
                  profile.username,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${profile.plan} · ${profile.email}'),
              ),
            ),
            const SizedBox(height: 12),
            StorageUsageCard(
              profile: profile,
              refreshing: _refreshingProfile || auth.loading,
              onRefresh: () => _refreshProfile(),
            ),
            const SizedBox(height: 12),
          ],
          FoldersBackupCard(
            folders: settings.backupFolders,
            manualController: _manualController,
            picking: _picking,
            onPickFolder: _pickFolder,
            onAddPath: _addManual,
            onRemoveFolder: settings.removeFolder,
            onChangeAlbum: _changeAlbum,
          ),
          const SizedBox(height: 12),
          const AppearanceCard(),
          const SizedBox(height: 12),
          const LanguageCard(),
          const SizedBox(height: 12),
          const FullSyncCard(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout),
            label: Text(s.logOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            s.appVersionLabel(AppInfo.displayVersion),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            AppInfo.websiteHost,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
