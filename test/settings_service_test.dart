import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/models/backup_folder.dart';
import 'package:pixelfox_mobile/services/settings_service.dart';
import 'package:pixelfox_mobile/services/storage.dart';

void main() {
  test('folder selection is persisted and reloaded', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);

    await settings.setFolders([
      '/photos/camera',
      '/photos/camera', // duplicate
      '  /photos/screenshots  ',
      '',
    ]);

    expect(settings.folders, ['/photos/camera', '/photos/screenshots']);

    final raw = await prefs.getString(kSelectedFoldersKey);
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List;
    expect(decoded.length, 2);
    expect(decoded[0]['path'], '/photos/camera');

    final reloaded = SettingsService(prefs: prefs);
    await reloaded.load();
    expect(reloaded.folders, ['/photos/camera', '/photos/screenshots']);
    expect(reloaded.hasFolders, isTrue);
  });

  test('add and remove folder update persistence mapping', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);

    await settings.addFolder('/a');
    await settings.addFolder('/b');
    expect(settings.folders, ['/a', '/b']);

    await settings.removeFolder('/a');
    expect(settings.folders, ['/b']);

    await settings.clearFolders();
    expect(settings.folders, isEmpty);
    expect(settings.hasFolders, isFalse);
  });

  test('folder can be bound to a Pixelfox album', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);

    await settings.addFolder(
      '/photos/vacation',
      albumId: 19,
      albumTitle: 'test',
    );
    expect(settings.backupFolders.single.albumId, 19);
    expect(settings.backupFolders.single.albumTitle, 'test');
    expect(settings.albumIdForFile('/photos/vacation/a.jpg'), 19);
    expect(settings.albumIdForFile('/other/x.jpg'), isNull);

    await settings.updateFolderAlbum('/photos/vacation'); // clear
    expect(settings.backupFolders.single.albumId, isNull);
  });

  test('migrates legacy plain string folder list', () async {
    final prefs = MemoryPrefsStore();
    await prefs.setString(
      kSelectedFoldersKey,
      jsonEncode(['/old/path', '/second']),
    );
    final settings = SettingsService(prefs: prefs);
    await settings.load();
    expect(settings.folders, ['/old/path', '/second']);
    expect(settings.backupFolders.every((f) => f.albumId == null), isTrue);
  });

  test('matchingFolder prefers longest path', () {
    final folders = [
      const BackupFolder(path: '/photos', albumId: 1, albumTitle: 'all'),
      const BackupFolder(path: '/photos/cam', albumId: 2, albumTitle: 'cam'),
    ];
    final m = BackupFolder.matchingFolder('/photos/cam/x.jpg', folders);
    expect(m?.albumId, 2);
  });
}
