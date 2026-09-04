import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fotoly_mobile/models/backup_status.dart';
import 'package:fotoly_mobile/services/backup_errors.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/backup_service.dart';
import 'package:fotoly_mobile/services/file_scanner.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/settings_service.dart';
import 'package:fotoly_mobile/services/storage.dart';

import 'fake_api_http.dart';

void main() {
  late String sessionFixture;
  late String uploadFixture;

  setUpAll(() {
    sessionFixture = File(
      'test/fixtures/upload_session.json',
    ).readAsStringSync();
    uploadFixture = File('test/fixtures/upload_result.json').readAsStringSync();
  });

  BackupService buildBackup({
    required SettingsService settings,
    required FileScanner scanner,
    required FakeApiHttp fake,
    BackupLedger? ledger,
  }) {
    return BackupService(
      settings: settings,
      scanner: scanner,
      ledger: ledger ?? BackupLedger(prefs: MemoryPrefsStore()),
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
      readBytes: (path) async => [1, 2, 3, 4],
    );
  }

  test('enumerates only files under selected folders', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos/keep']);

    final scanner = FakeFileScanner([
      const LocalImageFile(
        path: '/photos/keep/a.jpg',
        name: 'a.jpg',
        sizeBytes: 10,
      ),
      const LocalImageFile(
        path: '/photos/skip/b.jpg',
        name: 'b.jpg',
        sizeBytes: 10,
      ),
      const LocalImageFile(
        path: '/photos/keep/nested/c.png',
        name: 'c.png',
        sizeBytes: 20,
      ),
    ]);

    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );

    final backup = buildBackup(
      settings: settings,
      scanner: scanner,
      fake: fake,
    );

    final files = await backup.enumerateSelected();
    expect(files.map((f) => f.path).toList(), [
      '/photos/keep/a.jpg',
      '/photos/keep/nested/c.png',
    ]);
  });

  test(
    'job advances working → success when queue empties without failures',
    () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final scanner = FakeFileScanner([
        const LocalImageFile(
          path: '/photos/1.jpg',
          name: '1.jpg',
          sizeBytes: 4,
        ),
        const LocalImageFile(
          path: '/photos/2.jpg',
          name: '2.jpg',
          sizeBytes: 4,
        ),
      ]);

      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );

      final phases = <BackupPhase>[];
      final backup = buildBackup(
        settings: settings,
        scanner: scanner,
        fake: fake,
      );
      backup.addListener(() {
        phases.add(backup.status.phase);
      });

      final finalStatus = await backup.startBackup();

      expect(finalStatus.phase, BackupPhase.success);
      expect(finalStatus.completed, 2);
      expect(finalStatus.failed, 0);
      expect(finalStatus.total, 2);
      expect(phases, contains(BackupPhase.working));
      expect(phases.last, BackupPhase.success);
      expect(fake.sent.whereType<http.MultipartRequest>().length, 2);
    },
  );

  test('skips already secured files and only uploads new ones', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    final ledger = BackupLedger(prefs: prefs);
    const oldFile = LocalImageFile(
      path: '/photos/old.jpg',
      name: 'old.jpg',
      sizeBytes: 4,
    );
    await ledger.markUploaded(oldFile, imageUuid: 'already');

    final scanner = FakeFileScanner([
      oldFile,
      const LocalImageFile(
        path: '/photos/new.jpg',
        name: 'new.jpg',
        sizeBytes: 4,
      ),
    ]);

    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );

    final backup = buildBackup(
      settings: settings,
      scanner: scanner,
      fake: fake,
      ledger: ledger,
    );

    await backup.refreshInventory();
    expect(backup.pendingCount, 1);
    expect(backup.pendingImages.single.name, 'new.jpg');
    expect(backup.securedCount, 1);

    final status = await backup.startBackup();
    expect(status.phase, BackupPhase.success);
    expect(status.completed, 1);
    expect(status.total, 1);
    // Only the new file was uploaded.
    expect(fake.sent.whereType<http.MultipartRequest>().length, 1);

    // Second run uploads nothing again.
    final fake2 = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final backup2 = buildBackup(
      settings: settings,
      scanner: scanner,
      fake: fake2,
      ledger: ledger,
    );
    await backup2.startBackup();
    expect(fake2.sent.whereType<http.MultipartRequest>(), isEmpty);
    expect(backup2.pendingCount, 0);
  });

  test('refreshInventory lists newly added files as not yet secured', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    final mutable = <LocalImageFile>[
      const LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
    ];
    final scanner = _MutableScanner(mutable);

    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final ledger = BackupLedger(prefs: prefs);
    final backup = buildBackup(
      settings: settings,
      scanner: scanner,
      fake: fake,
      ledger: ledger,
    );

    await backup.startBackup();
    expect(backup.pendingCount, 0);

    mutable.add(
      const LocalImageFile(path: '/photos/2.jpg', name: '2.jpg', sizeBytes: 4),
    );
    await backup.refreshInventory();
    expect(backup.pendingCount, 1);
    expect(backup.pendingImages.single.name, '2.jpg');
  });

  test('deriveBackupStatus maps counters to working vs success', () {
    final working = deriveBackupStatus(
      running: true,
      completed: 1,
      total: 3,
      failed: 0,
      currentFileName: 'mid.jpg',
    );
    expect(working.phase, BackupPhase.working);
    expect(working.currentFileName, 'mid.jpg');

    final success = deriveBackupStatus(
      running: false,
      completed: 3,
      total: 3,
      failed: 0,
    );
    expect(success.phase, BackupPhase.success);

    final idle = deriveBackupStatus(
      running: false,
      completed: 0,
      total: 0,
      failed: 0,
    );
    expect(idle.phase, BackupPhase.idle);
  });

  test('auto-scan tick picks up newly added images without re-upload', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    final mutable = <LocalImageFile>[
      const LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
    ];
    final scanner = _MutableScanner(mutable);
    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final ledger = BackupLedger(prefs: prefs);
    final backup = buildBackup(
      settings: settings,
      scanner: scanner,
      fake: fake,
      ledger: ledger,
    );

    await backup.startBackup();
    expect(backup.pendingCount, 0);

    mutable.add(
      const LocalImageFile(
        path: '/photos/new.jpg',
        name: 'new.jpg',
        sizeBytes: 4,
      ),
    );

    // Simulate one 30s auto-scan cycle (no throttle so the test is deterministic).
    await backup.autoScanTickForTest(throttle: false);
    expect(backup.autoScanTicks, 1);
    expect(backup.pendingCount, 1);
    expect(backup.pendingImages.single.name, 'new.jpg');

    backup.startAutoScan(interval: const Duration(hours: 1));
    expect(backup.autoScanEnabled, isTrue);
    // Second start with default interval replaces the custom one only when
    // interval is passed; default-interval no-op is covered below.
    backup.stopAutoScan();
    expect(backup.autoScanEnabled, isFalse);
  });

  test('quiet inventory never exposes scanning UI mid-scan', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    final gate = Completer<void>();
    final scanner = _DelayedScanner(const [
      LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
    ], gate.future);
    final backup = BackupService(
      settings: settings,
      scanner: scanner,
      ledger: BackupLedger(prefs: prefs),
      clientProvider: () => throw StateError('no upload'),
      readBytes: (path) async => [1],
    );

    final observedScanning = <bool>[];
    backup.addListener(() {
      observedScanning.add(backup.scanning);
    });

    final future = backup.refreshInventory(quiet: true);
    // Allow microtasks so the scan reaches the delay.
    await Future<void>.delayed(Duration.zero);
    expect(backup.scanInProgress, isTrue);
    expect(backup.scanning, isFalse); // UI must stay calm

    // Lifecycle-style notify must not flip the spinner on either.
    backup.startAutoScan(interval: const Duration(hours: 1));
    expect(backup.scanning, isFalse);

    gate.complete();
    await future;
    expect(backup.scanning, isFalse);
    expect(backup.scanInProgress, isFalse);
    expect(backup.pendingCount, 1);
    // No listener saw scanning == true during quiet work.
    expect(observedScanning, isNot(contains(true)));
    backup.dispose();
  });

  test('throttled quiet scan skips when inventory is fresh', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    var scanCalls = 0;
    final scanner = _CountingScanner(() {
      scanCalls++;
      return [
        const LocalImageFile(
          path: '/photos/1.jpg',
          name: '1.jpg',
          sizeBytes: 4,
        ),
      ];
    });
    final backup = BackupService(
      settings: settings,
      scanner: scanner,
      ledger: BackupLedger(prefs: prefs),
      clientProvider: () => throw StateError('no upload'),
      readBytes: (path) async => [1],
      minAutoInventoryInterval: const Duration(seconds: 30),
    );

    await backup.refreshInventory(quiet: true);
    expect(scanCalls, 1);

    await backup.refreshInventory(quiet: true, throttle: true);
    expect(scanCalls, 1); // skipped

    // Manual / non-throttled always runs.
    await backup.refreshInventory(quiet: true, throttle: false);
    expect(scanCalls, 2);
    backup.dispose();
  });

  test('startAutoScan is a no-op when already running', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    final backup = BackupService(
      settings: settings,
      scanner: FakeFileScanner(const []),
      ledger: BackupLedger(prefs: prefs),
      clientProvider: () => throw StateError('no upload'),
    );

    var notifies = 0;
    backup.addListener(() => notifies++);

    backup.startAutoScan(interval: const Duration(hours: 1));
    expect(backup.autoScanEnabled, isTrue);
    final afterFirst = notifies;

    backup.startAutoScan(); // default interval, already running → no-op
    expect(notifies, afterFirst);
    backup.dispose();
  });

  test('concurrent refreshInventory coalesces into a follow-up scan', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    final gate = Completer<void>();
    final firstBatch = [
      const LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
    ];
    final secondBatch = [
      const LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
      const LocalImageFile(path: '/photos/2.jpg', name: '2.jpg', sizeBytes: 4),
    ];
    final scanner = _SequenceDelayedScanner(
      batches: [firstBatch, secondBatch],
      gate: gate.future,
    );
    final backup = BackupService(
      settings: settings,
      scanner: scanner,
      ledger: BackupLedger(prefs: prefs),
      clientProvider: () => throw StateError('no upload'),
      readBytes: (path) async => [1],
    );

    final first = backup.refreshInventory(quiet: true);
    await Future<void>.delayed(Duration.zero);
    expect(backup.scanInProgress, isTrue);

    // Folder-change style request while quiet scan is mid-flight.
    final second = backup.refreshInventory();
    gate.complete();
    await Future.wait([first, second]);

    expect(scanner.scanCalls, 2);
    expect(backup.pendingCount, 2);
    expect(backup.scanInProgress, isFalse);
    backup.dispose();
  });

  test('failed inventory does not arm auto-scan throttle', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);

    final scanner = _ToggleFailScanner();
    final backup = BackupService(
      settings: settings,
      scanner: scanner,
      ledger: BackupLedger(prefs: prefs),
      clientProvider: () => throw StateError('no upload'),
      readBytes: (path) async => [1],
      minAutoInventoryInterval: const Duration(hours: 1),
    );

    scanner.fail = true;
    await backup.refreshInventory(quiet: true);
    expect(backup.status.phase, BackupPhase.failed);
    expect(backup.lastInventoryFinishedAt, isNull);
    expect(backup.shouldThrottleAutoInventory, isFalse);

    scanner.fail = false;
    await backup.refreshInventory(quiet: true, throttle: true);
    expect(backup.status.phase, BackupPhase.idle);
    expect(backup.allImages, isNotEmpty);
    expect(backup.lastInventoryFinishedAt, isNotNull);
    expect(backup.shouldThrottleAutoInventory, isTrue);
    backup.dispose();
  });

  test(
    'startBackup waits for in-flight quiet inventory before its own scan',
    () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final gate = Completer<void>();
      var scanCalls = 0;
      final scanner = _CallbackScanner((_) async {
        scanCalls++;
        if (scanCalls == 1) {
          await gate.future;
        }
        return const [
          LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
        ];
      });
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final backup = buildBackup(
        settings: settings,
        scanner: scanner,
        fake: fake,
      );

      final quiet = backup.refreshInventory(quiet: true);
      await Future<void>.delayed(Duration.zero);
      expect(backup.scanInProgress, isTrue);

      final backupFuture = backup.startBackup();
      // Quiet scan still held the gate; backup must not have started its walk.
      await Future<void>.delayed(Duration.zero);
      expect(scanCalls, 1);

      gate.complete();
      await quiet;
      final status = await backupFuture;
      expect(status.phase, BackupPhase.success);
      // quiet scan + startBackup rescan (+ finally refreshInventory)
      expect(scanCalls, greaterThanOrEqualTo(2));
      backup.dispose();
    },
  );

  test(
    'refreshInventory clears sticky error after a later successful scan',
    () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final scanner = _ToggleFailScanner();
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final backup = buildBackup(
        settings: settings,
        scanner: scanner,
        fake: fake,
      );

      scanner.fail = true;
      await backup.refreshInventory();
      expect(backup.status.phase, BackupPhase.failed);
      expect(backup.status.message, BackupErrorCodes.foldersInaccessible);

      scanner.fail = false;
      await backup.refreshInventory();
      expect(backup.status.phase, BackupPhase.idle);
      expect(backup.status.message, isNull);
      expect(backup.allImages, isNotEmpty);
    },
  );

  group('fullSyncRemote', () {
    test('removes only missing remote images; keeps no-uuid entries', () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final ledger = BackupLedger(prefs: prefs);
      const present = LocalImageFile(
        path: '/photos/present.jpg',
        name: 'present.jpg',
        sizeBytes: 10,
      );
      const missing = LocalImageFile(
        path: '/photos/missing.jpg',
        name: 'missing.jpg',
        sizeBytes: 20,
      );
      const noUuid = LocalImageFile(
        path: '/photos/legacy.jpg',
        name: 'legacy.jpg',
        sizeBytes: 30,
      );
      await ledger.markUploaded(present, imageUuid: 'uuid-present');
      await ledger.markUploaded(missing, imageUuid: 'uuid-missing');
      await ledger.markUploaded(noUuid);

      final scanner = FakeFileScanner([present, missing, noUuid]);
      final fake = FakeApiHttp(
        imageStatusByUuid: {'uuid-present': 200, 'uuid-missing': 404},
      );

      final backup = buildBackup(
        settings: settings,
        scanner: scanner,
        fake: fake,
        ledger: ledger,
      );

      final result = await backup.fullSyncRemote();

      expect(result.busy, isFalse);
      expect(result.checked, 2);
      expect(result.stillPresent, 1);
      expect(result.removed, 1);
      expect(result.skippedNoUuid, 1);
      expect(result.errors, 0);
      expect(result.abortedAuth, isFalse);

      expect(ledger.isBackedUp(present), isTrue);
      expect(ledger.isBackedUp(missing), isFalse);
      expect(ledger.isBackedUp(noUuid), isTrue);

      // Inventory refreshed: missing is pending again.
      expect(backup.pendingCount, 1);
      expect(backup.pendingImages.single.path, missing.path);
      expect(backup.securedCount, 2);

      // No upload sessions during full sync.
      expect(fake.sent.any((r) => r.url.path.contains('upload')), isFalse);
    });

    test('treats 5xx as error without removing entry', () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final ledger = BackupLedger(prefs: prefs);
      const file = LocalImageFile(
        path: '/photos/a.jpg',
        name: 'a.jpg',
        sizeBytes: 4,
      );
      await ledger.markUploaded(file, imageUuid: 'uuid-a');

      final fake = FakeApiHttp(
        imageStatusByUuid: {'uuid-a': 500},
        defaultImageBody: '{"error":"server"}',
      );
      final backup = buildBackup(
        settings: settings,
        scanner: FakeFileScanner([file]),
        fake: fake,
        ledger: ledger,
      );

      final result = await backup.fullSyncRemote();
      expect(result.checked, 1);
      expect(result.errors, 1);
      expect(result.removed, 0);
      expect(ledger.isBackedUp(file), isTrue);
    });

    test('aborts on 401 and does not remove remaining entries', () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final ledger = BackupLedger(prefs: prefs);
      const a = LocalImageFile(
        path: '/photos/a.jpg',
        name: 'a.jpg',
        sizeBytes: 1,
      );
      const b = LocalImageFile(
        path: '/photos/b.jpg',
        name: 'b.jpg',
        sizeBytes: 2,
      );
      await ledger.markUploaded(a, imageUuid: 'uuid-a');
      await ledger.markUploaded(b, imageUuid: 'uuid-b');

      // First check 401 → abort before second.
      final fake = FakeApiHttp(
        imageStatusByUuid: {'uuid-a': 401, 'uuid-b': 404},
      );
      final backup = buildBackup(
        settings: settings,
        scanner: FakeFileScanner([a, b]),
        fake: fake,
        ledger: ledger,
      );

      final result = await backup.fullSyncRemote();
      expect(result.abortedAuth, isTrue);
      expect(result.errors, 1);
      // Neither removed: a failed auth; b never checked (or if map order differs,
      // at least entries with 401 path abort — map iteration order is insertion).
      expect(ledger.isBackedUp(a), isTrue);
      expect(ledger.isBackedUp(b), isTrue);
    });

    test('returns busy when backup is running', () async {
      final prefs = MemoryPrefsStore();
      final settings = SettingsService(prefs: prefs);
      await settings.setFolders(['/photos']);

      final gate = Completer<void>();
      final scanner = _DelayedScanner(const [
        LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
      ], gate.future);
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final backup = buildBackup(
        settings: settings,
        scanner: scanner,
        fake: fake,
      );

      final backupFuture = backup.startBackup();
      var sawRunning = false;
      for (var i = 0; i < 100; i++) {
        if (backup.running) {
          sawRunning = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        sawRunning,
        isTrue,
        reason: 'backup should be running before sync',
      );

      final syncResult = await backup.fullSyncRemote();
      expect(syncResult.busy, isTrue);

      gate.complete();
      await backupFuture;
    });
  });
}

class _MutableScanner implements FileScanner {
  _MutableScanner(this.files);

  final List<LocalImageFile> files;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async => List.of(files);
}

class _ToggleFailScanner implements FileScanner {
  bool fail = false;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async {
    if (fail) {
      throw const FoldersInaccessibleException(['/photos']);
    }
    return const [
      LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
    ];
  }
}

class _DelayedScanner implements FileScanner {
  _DelayedScanner(this.files, this.gate);

  final List<LocalImageFile> files;
  final Future<void> gate;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async {
    await gate;
    return List.of(files);
  }
}

class _CountingScanner implements FileScanner {
  _CountingScanner(this._build);

  final List<LocalImageFile> Function() _build;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async => _build();
}

class _SequenceDelayedScanner implements FileScanner {
  _SequenceDelayedScanner({required this.batches, required this.gate});

  final List<List<LocalImageFile>> batches;
  final Future<void> gate;
  int scanCalls = 0;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async {
    final index = scanCalls;
    scanCalls++;
    if (index == 0) {
      await gate;
    }
    final batch = index < batches.length ? batches[index] : batches.last;
    return List.of(batch);
  }
}

class _CallbackScanner implements FileScanner {
  _CallbackScanner(this._scan);

  final Future<List<LocalImageFile>> Function(List<String> folders) _scan;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) => _scan(folders);
}
