import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fotoly_mobile/models/backup_status.dart';
import 'package:fotoly_mobile/models/upload_result.dart';
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
    bool Function()? serverReachable,
    int? Function()? accountUserId,
  }) {
    return BackupService(
      settings: settings,
      scanner: scanner,
      ledger: ledger ?? BackupLedger(prefs: MemoryPrefsStore()),
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
      readBytes: (path) async => [1, 2, 3, 4],
      serverReachable: serverReachable,
      accountUserId: accountUserId,
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

  test('startBackup loads the account ledger before uploading', () async {
    final prefs = MemoryPrefsStore();
    final settings = SettingsService(prefs: prefs);
    await settings.setFolders(['/photos']);
    const file = LocalImageFile(
      path: '/photos/old.jpg',
      name: 'old.jpg',
      sizeBytes: 4,
    );
    final seeded = BackupLedger(prefs: prefs);
    await seeded.load(userId: 7);
    await seeded.markUploaded(file, imageUuid: 'already');

    final fresh = BackupLedger(prefs: prefs);
    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final backup = buildBackup(
      settings: settings,
      scanner: FakeFileScanner([file]),
      fake: fake,
      ledger: fresh,
      accountUserId: () => 7,
    );

    final status = await backup.startBackup();

    expect(status.phase, BackupPhase.idle);
    expect(status.completed, 0);
    expect(backup.pendingCount, 0);
    expect(backup.securedCount, 1);
    expect(fake.sent.whereType<http.MultipartRequest>(), isEmpty);
    expect(fresh.isBoundTo(7), isTrue);
    expect(fresh.isBackedUp(file), isTrue);
  });

  test('backup waits for an account ledger that is already loading', () async {
    final prefs = _DelayedLedgerPrefs(7);
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    const file = LocalImageFile(
      path: '/photos/old.jpg',
      name: 'old.jpg',
      sizeBytes: 4,
    );
    final seeded = BackupLedger(prefs: prefs);
    await seeded.markUploaded(file, imageUuid: 'already');
    final saved = await prefs.getString(kBackupLedgerKey);
    await prefs.setString(backupLedgerKeyForUser(7), saved!);

    final ledger = BackupLedger(prefs: prefs);
    final fake = FakeApiHttp(
      sessionBody: sessionFixture,
      uploadBody: uploadFixture,
    );
    final backup = buildBackup(
      settings: settings,
      scanner: FakeFileScanner([file]),
      fake: fake,
      ledger: ledger,
      accountUserId: () => 7,
    );
    final loading = ledger.ensureUser(7);
    final job = backup.startBackup();
    await Future<void>.delayed(Duration.zero);
    final requestsWhileLoading = fake.sent.length;
    prefs.release.complete();
    await loading;
    final result = await job;

    expect(requestsWhileLoading, 0);
    expect(fake.sent, isEmpty);
    expect(result.completed, 0);
    expect(backup.securedCount, 1);
  });

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
    test('returns busy while backup is still preparing', () async {
      final prefs = _DelayedLedgerPrefs(7);
      final settings = SettingsService(prefs: MemoryPrefsStore());
      await settings.setFolders(['/photos']);
      final backup = buildBackup(
        settings: settings,
        scanner: FakeFileScanner([]),
        fake: FakeApiHttp(),
        ledger: BackupLedger(prefs: prefs),
        accountUserId: () => 7,
      );
      final job = backup.startBackup();
      final sync = backup.fullSyncRemote();
      prefs.release.complete();
      await job;

      expect((await sync).busy, isTrue);
      expect((await backup.fullSyncRemote()).busy, isFalse);
    });

    test('only one full sync starts while the ledger loads', () async {
      final prefs = _DelayedLedgerPrefs(7);
      final backup = buildBackup(
        settings: SettingsService(prefs: MemoryPrefsStore()),
        scanner: FakeFileScanner([]),
        fake: FakeApiHttp(),
        ledger: BackupLedger(prefs: prefs),
        accountUserId: () => 7,
      );
      final first = backup.fullSyncRemote();
      final second = backup.fullSyncRemote();
      prefs.release.complete();

      expect((await first).busy, isFalse);
      expect((await second).busy, isTrue);
    });

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

    test('full sync persists removals once', () async {
      final prefs = _CountingPrefs();
      final settings = SettingsService(prefs: MemoryPrefsStore());
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
      const c = LocalImageFile(
        path: '/photos/c.jpg',
        name: 'c.jpg',
        sizeBytes: 3,
      );
      await ledger.markUploaded(a, imageUuid: 'uuid-a');
      await ledger.markUploaded(b, imageUuid: 'uuid-b');
      await ledger.markUploaded(c, imageUuid: 'uuid-c');
      expect(prefs.writes, 3);

      final backup = buildBackup(
        settings: settings,
        scanner: FakeFileScanner([a, b, c]),
        fake: FakeApiHttp(
          imageStatusByUuid: {'uuid-a': 404, 'uuid-b': 404, 'uuid-c': 404},
        ),
        ledger: ledger,
      );

      final result = await backup.fullSyncRemote();
      expect(result.removed, 3);
      expect(prefs.writes, 4);

      final reloaded = BackupLedger(prefs: prefs.inner);
      await reloaded.load();
      expect(reloaded.count, 0);
    });
  });

  test(
    'each upload moves its file without reclassifying the inventory',
    () async {
      final settings = SettingsService(prefs: MemoryPrefsStore());
      await settings.setFolders(['/photos']);
      final files = List.generate(
        12,
        (i) => LocalImageFile(
          path: '/photos/$i.jpg',
          name: '$i.jpg',
          sizeBytes: 4,
        ),
      );
      final ledger = _CountingLedger(prefs: MemoryPrefsStore());
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final backup = buildBackup(
        settings: settings,
        scanner: FakeFileScanner(files),
        fake: fake,
        ledger: ledger,
      );
      addTearDown(backup.dispose);
      final securedDuringRun = <int>{};
      backup.addListener(() {
        if (backup.running && backup.status.total == files.length) {
          securedDuringRun.add(backup.securedCount);
          expect(backup.pendingCount + backup.securedCount, files.length);
        }
      });

      final result = await backup.startBackup();

      expect(result.completed, files.length);
      expect(securedDuringRun, containsAll(List.generate(13, (i) => i)));
      expect(ledger.classifications, files.length * 2);
      expect(backup.pendingImages, isEmpty);
    },
  );

  test('an unchanged automatic scan skips inventory classification', () async {
    final folder = await Directory.systemTemp.createTemp('fotoly_inventory_');
    addTearDown(() => folder.delete(recursive: true));
    await File('${folder.path}/photo.jpg').writeAsBytes([1]);
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders([folder.path]);
    final ledger = _CountingLedger(prefs: MemoryPrefsStore());
    final backup = BackupService(
      settings: settings,
      ledger: ledger,
      clientProvider: () => throw StateError('no upload'),
    );
    addTearDown(backup.dispose);

    await backup.refreshInventory();
    expect(ledger.classifications, 1);
    await backup.autoScanTickForTest(throttle: false);
    expect(ledger.classifications, 1);

    await File('${folder.path}/photo.jpg').writeAsBytes([1, 2]);
    await backup.refreshInventory();
    expect(backup.pendingImages.single.sizeBytes, 2);
    expect(ledger.classifications, 2);
  });

  test('backup writes the ledger once for a short run', () async {
    final prefs = _CountingPrefs();
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final files = [
      for (var i = 0; i < 3; i++)
        LocalImageFile(path: '/photos/$i.jpg', name: '$i.jpg', sizeBytes: 4),
    ];
    final backup = buildBackup(
      settings: settings,
      scanner: FakeFileScanner(files),
      fake: FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      ),
      ledger: BackupLedger(prefs: prefs),
    );

    await backup.startBackup();
    expect(backup.status.completed, 3);
    expect(prefs.writes, 1);

    final reloaded = BackupLedger(prefs: prefs.inner);
    await reloaded.load();
    expect(reloaded.count, 3);
  });

  test('backup flushes the ledger every stride and at the end', () async {
    final prefs = _CountingPrefs();
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final files = [
      for (var i = 0; i < 3; i++)
        LocalImageFile(path: '/photos/$i.jpg', name: '$i.jpg', sizeBytes: 4),
    ];
    final backup = BackupService(
      settings: settings,
      scanner: FakeFileScanner(files),
      ledger: BackupLedger(prefs: prefs),
      ledgerFlushStride: 2,
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          sessionStatus: 200,
          sessionBody: sessionFixture,
          uploadStatus: 200,
          uploadBody: uploadFixture,
        ),
      ),
      readBytes: (path) async => [1, 2, 3, 4],
    );

    await backup.startBackup();
    expect(prefs.writes, 2);
    backup.dispose();
  });

  test('backup streams the file and records the size on disk', () async {
    final root = await Directory.systemTemp.createTemp('fotoly_backup_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final image = File('${root.path}/a.jpg');
    await image.writeAsBytes([9, 8, 7, 6, 5]);

    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders([root.path]);
    final prefs = MemoryPrefsStore();
    final ledger = BackupLedger(prefs: prefs);
    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final client = _RecordingClient(fake);
    final backup = BackupService(
      settings: settings,
      scanner: FakeFileScanner([
        LocalImageFile(path: image.path, name: 'a.jpg', sizeBytes: 4),
      ]),
      ledger: ledger,
      clientProvider: () => client,
    );

    final status = await backup.startBackup();
    expect(status.completed, 1);
    expect(client.streamUploads, 1);
    expect(client.byteUploads, 0);
    expect(
      fake.sent.whereType<http.MultipartRequest>().single.files.single.length,
      5,
    );

    final onDisk = LocalImageFile(
      path: image.path,
      name: 'a.jpg',
      sizeBytes: 5,
    );
    expect(ledger.isBackedUp(onDisk), isTrue);
    final reloaded = BackupLedger(prefs: prefs);
    await reloaded.load();
    expect(reloaded.isBackedUp(onDisk), isTrue);
    backup.dispose();
  });

  test('quiet rescan stays silent until a file size changes', () async {
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final files = <LocalImageFile>[
      const LocalImageFile(path: '/photos/1.jpg', name: '1.jpg', sizeBytes: 4),
    ];
    final backup = BackupService(
      settings: settings,
      scanner: _MutableScanner(files),
      ledger: BackupLedger(prefs: MemoryPrefsStore()),
      clientProvider: () => throw StateError('no upload'),
      readBytes: (path) async => [1],
    );
    var notifies = 0;
    backup.addListener(() => notifies++);

    await backup.refreshInventory(quiet: true);
    final afterFirst = notifies;
    expect(backup.pendingCount, 1);

    await backup.refreshInventory(quiet: true, throttle: false);
    expect(notifies, afterFirst);

    files[0] = const LocalImageFile(
      path: '/photos/1.jpg',
      name: '1.jpg',
      sizeBytes: 9,
    );
    await backup.refreshInventory(quiet: true, throttle: false);
    expect(backup.pendingImages.single.sizeBytes, 9);
    expect(notifies, greaterThan(afterFirst));
    backup.dispose();
  });

  test(
    'oversized files are not uploaded and return after a plan upgrade',
    () async {
      final settings = SettingsService(prefs: MemoryPrefsStore());
      await settings.setFolders(['/photos']);
      var limit = 25 * 1024 * 1024;
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final backup = BackupService(
        settings: settings,
        scanner: FakeFileScanner([
          const LocalImageFile(
            path: '/photos/ok.jpg',
            name: 'ok.jpg',
            sizeBytes: 4,
          ),
          LocalImageFile(
            path: '/photos/big.jpg',
            name: 'big.jpg',
            sizeBytes: limit + 1,
          ),
        ]),
        ledger: BackupLedger(prefs: MemoryPrefsStore()),
        clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
        readBytes: (path) async => [1, 2, 3, 4],
        maxUploadBytes: () => limit,
      );

      await backup.refreshInventory();
      expect(backup.pendingImages.map((file) => file.name), ['ok.jpg']);
      expect(backup.tooLargeImages.map((file) => file.name), ['big.jpg']);

      final status = await backup.startBackup();
      expect(status.failed, 0);
      expect(status.completed, 1);
      expect(fake.sent.whereType<http.MultipartRequest>(), hasLength(1));
      expect(backup.tooLargeImages.map((file) => file.name), ['big.jpg']);
      expect(backup.pendingCount, 0);

      limit = 50 * 1024 * 1024;
      await backup.refreshInventory(throttle: false);
      expect(backup.tooLargeCount, 0);
      expect(backup.pendingImages.map((file) => file.name), ['big.jpg']);
      backup.dispose();
    },
  );

  test('a session size rejection is not a failed upload', () async {
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final session = sessionFixture.replaceFirst(
      '"max_bytes": 52428800',
      '"max_bytes": 3',
    );
    var limit = 50 * 1024 * 1024;
    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: session,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final backup = BackupService(
      settings: settings,
      scanner: FakeFileScanner([
        const LocalImageFile(
          path: '/photos/big.jpg',
          name: 'big.jpg',
          sizeBytes: 100,
        ),
      ]),
      ledger: BackupLedger(prefs: MemoryPrefsStore()),
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
      readBytes: (path) async => [1, 2, 3, 4],
      maxUploadBytes: () => limit,
    );

    final status = await backup.startBackup();
    expect(status.failed, 0);
    expect(status.phase, BackupPhase.idle);
    expect(backup.tooLargeImages.single.name, 'big.jpg');
    expect(backup.pendingCount, 0);
    final requests = fake.sent.length;
    expect(requests, 1);

    await backup.startBackup();
    expect(fake.sent.length, requests);

    limit += 1;
    await backup.refreshInventory(throttle: false);
    expect(backup.pendingCount, 1);
    expect(backup.tooLargeCount, 0);
    backup.dispose();
  });

  test(
    'a ceiling captured against a stale higher plan clears on a middle tier',
    () async {
      final settings = SettingsService(prefs: MemoryPrefsStore());
      await settings.setFolders(['/photos']);
      // Same shape as a stale 100 MiB cache, a 25 MiB server cap, and a
      // 40 MiB file that fits the later 50 MiB plan. Small numbers keep the
      // test off a real 25 MiB buffer: readBytes is what the client measures.
      final session = sessionFixture.replaceFirst(
        '"max_bytes": 52428800',
        '"max_bytes": 3',
      );
      var limit = 1000;
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: session,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final backup = BackupService(
        settings: settings,
        scanner: FakeFileScanner([
          const LocalImageFile(
            path: '/photos/mid.jpg',
            name: 'mid.jpg',
            sizeBytes: 100,
          ),
        ]),
        ledger: BackupLedger(prefs: MemoryPrefsStore()),
        clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
        readBytes: (path) async => [1, 2, 3, 4],
        maxUploadBytes: () => limit,
      );

      final status = await backup.startBackup();
      expect(status.failed, 0);
      expect(backup.tooLargeImages.single.name, 'mid.jpg');

      // Middle tier fits the file, but it is still below the stale snapshot.
      limit = 200;
      await backup.refreshInventory(throttle: false);
      expect(backup.pendingImages.map((file) => file.name), ['mid.jpg']);
      expect(backup.tooLargeCount, 0);
      backup.dispose();
    },
  );

  test('startBackup while offline does not upload', () async {
    final settings = SettingsService(prefs: MemoryPrefsStore());
    await settings.setFolders(['/photos']);
    final fake = FakeApiHttp(
      sessionStatus: 200,
      sessionBody: sessionFixture,
      uploadStatus: 200,
      uploadBody: uploadFixture,
    );
    final backup = buildBackup(
      settings: settings,
      scanner: FakeFileScanner([
        const LocalImageFile(
          path: '/photos/a.jpg',
          name: 'a.jpg',
          sizeBytes: 4,
        ),
      ]),
      fake: fake,
      serverReachable: () => false,
    );

    final status = await backup.startBackup();
    expect(status.phase, BackupPhase.failed);
    expect(status.message, BackupErrorCodes.offline);
    expect(status.failed, 0);
    expect(fake.sent, isEmpty);
    backup.dispose();
  });
}

class _CountingLedger extends BackupLedger {
  _CountingLedger({required super.prefs});

  int classifications = 0;

  @override
  bool isBackedUp(LocalImageFile file) {
    classifications++;
    return super.isBackedUp(file);
  }
}

class _CountingPrefs implements PrefsStore {
  final MemoryPrefsStore inner = MemoryPrefsStore();
  int writes = 0;

  @override
  Future<String?> getString(String key) => inner.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    writes++;
    await inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => inner.remove(key);
}

class _DelayedLedgerPrefs extends MemoryPrefsStore {
  _DelayedLedgerPrefs(this.userId);

  final int userId;
  final release = Completer<void>();

  @override
  Future<String?> getString(String key) async {
    if (key == backupLedgerKeyForUser(userId)) await release.future;
    return super.getString(key);
  }
}

class _RecordingClient extends PixelfoxApiClient {
  _RecordingClient(FakeApiHttp fake) : super(apiKey: 'k', httpClient: fake);

  int streamUploads = 0;
  int byteUploads = 0;

  @override
  Future<UploadResult> uploadImageStream({
    required String filename,
    required int length,
    required Stream<List<int>> Function() openRead,
    bool originalOnly = true,
    int? albumId,
    bool? isNsfw,
    String fieldName = 'file',
  }) async {
    streamUploads++;
    return super.uploadImageStream(
      filename: filename,
      length: length,
      openRead: openRead,
      originalOnly: originalOnly,
      albumId: albumId,
      isNsfw: isNsfw,
      fieldName: fieldName,
    );
  }

  @override
  Future<UploadResult> uploadImageBytes({
    required String filename,
    required List<int> bytes,
    bool originalOnly = true,
    int? albumId,
    bool? isNsfw,
  }) async {
    byteUploads++;
    return super.uploadImageBytes(
      filename: filename,
      bytes: bytes,
      originalOnly: originalOnly,
      albumId: albumId,
      isNsfw: isNsfw,
    );
  }
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
