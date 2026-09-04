import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_brand.dart';
import '../models/backup_folder.dart';
import 'storage.dart';

String get kSelectedFoldersKey => AppBrand.current.selectedFoldersKey;

/// Persists which local folders the user wants backed up (+ optional album).
class SettingsService extends ChangeNotifier {
  SettingsService({required this._prefs});

  final PrefsStore _prefs;
  List<BackupFolder> _folders = [];
  bool _loaded = false;

  /// Full folder configs (path + album mapping).
  List<BackupFolder> get backupFolders => List.unmodifiable(_folders);

  /// Paths only — used by scanners / inventory.
  List<String> get folders =>
      List.unmodifiable(_folders.map((f) => f.path).toList());

  bool get loaded => _loaded;
  bool get hasFolders => _folders.isNotEmpty;

  Future<void> load() async {
    final raw = await _prefs.getString(kSelectedFoldersKey);
    if (raw == null || raw.isEmpty) {
      _folders = [];
    } else {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _folders = decoded.map(_parseEntry).whereType<BackupFolder>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));
      } else {
        _folders = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  BackupFolder? _parseEntry(dynamic entry) {
    // Legacy: plain path strings.
    if (entry is String) {
      final p = entry.trim();
      if (p.isEmpty) return null;
      return BackupFolder(path: p);
    }
    if (entry is Map) {
      final map = Map<String, dynamic>.from(entry);
      final path = (map['path'] as String?)?.trim() ?? '';
      if (path.isEmpty) return null;
      return BackupFolder.fromJson({...map, 'path': path});
    }
    return null;
  }

  Future<void> setBackupFolders(List<BackupFolder> folders) async {
    final byPath = <String, BackupFolder>{};
    for (final f in folders) {
      final p = f.path.trim();
      if (p.isEmpty) continue;
      byPath[p] = BackupFolder(
        path: p,
        albumId: f.albumId,
        albumTitle: f.albumTitle,
      );
    }
    _folders = byPath.values.toList()..sort((a, b) => a.path.compareTo(b.path));
    await _prefs.setString(
      kSelectedFoldersKey,
      jsonEncode(_folders.map((f) => f.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Legacy helper used by older tests — paths only, no album.
  Future<void> setFolders(List<String> paths) async {
    await setBackupFolders(paths.map((p) => BackupFolder(path: p)).toList());
  }

  Future<void> addFolder(
    String path, {
    int? albumId,
    String? albumTitle,
  }) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final existing = [..._folders];
    final idx = existing.indexWhere((f) => f.path == p);
    final next = BackupFolder(
      path: p,
      albumId: albumId,
      albumTitle: albumTitle,
    );
    if (idx >= 0) {
      existing[idx] = next;
    } else {
      existing.add(next);
    }
    await setBackupFolders(existing);
  }

  Future<void> updateFolderAlbum(
    String path, {
    int? albumId,
    String? albumTitle,
  }) async {
    final p = path.trim();
    final existing = [..._folders];
    final idx = existing.indexWhere((f) => f.path == p);
    if (idx < 0) return;
    if (albumId == null) {
      existing[idx] = existing[idx].copyWith(clearAlbum: true);
    } else {
      existing[idx] = existing[idx].copyWith(
        albumId: albumId,
        albumTitle: albumTitle,
      );
    }
    await setBackupFolders(existing);
  }

  Future<void> removeFolder(String path) async {
    await setBackupFolders(_folders.where((f) => f.path != path).toList());
  }

  Future<void> clearFolders() async {
    await setBackupFolders([]);
  }

  /// Album id for a local file based on longest matching folder mapping.
  int? albumIdForFile(String filePath) =>
      BackupFolder.matchingFolder(filePath, _folders)?.albumId;
}
