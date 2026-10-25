import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/services/backup_ledger.dart';
import 'package:fotoly_mobile/services/file_scanner.dart';
import 'package:fotoly_mobile/services/storage.dart';

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

void main() {
  test('marks uploads and skips same path+size', () async {
    final prefs = MemoryPrefsStore();
    final ledger = BackupLedger(prefs: prefs);

    const a = LocalImageFile(path: '/p/a.jpg', name: 'a.jpg', sizeBytes: 10);
    const aChanged = LocalImageFile(
      path: '/p/a.jpg',
      name: 'a.jpg',
      sizeBytes: 99,
    );
    const b = LocalImageFile(path: '/p/b.jpg', name: 'b.jpg', sizeBytes: 10);

    expect(ledger.isBackedUp(a), isFalse);
    await ledger.markUploaded(a, imageUuid: 'uuid-a');
    expect(ledger.isBackedUp(a), isTrue);
    expect(ledger.isBackedUp(aChanged), isFalse); // size changed → re-upload
    expect(ledger.isBackedUp(b), isFalse);

    final all = [a, aChanged, b];
    expect(ledger.pendingOf(all).map((f) => f.path).toList(), [
      '/p/a.jpg', // the size=99 variant
      '/p/b.jpg',
    ]);
    // pendingOf returns files that are NOT backed up — a (size 10) is backed up
    expect(ledger.pendingOf(all).map((f) => f.sizeBytes).toList(), [99, 10]);
    expect(ledger.alreadyOf(all), [a]);
  });

  test('ledger survives reload from prefs', () async {
    final prefs = MemoryPrefsStore();
    final ledger = BackupLedger(prefs: prefs);
    const file = LocalImageFile(
      path: '/photos/x.png',
      name: 'x.png',
      sizeBytes: 42,
    );
    await ledger.markUploaded(file, imageUuid: 'u1');

    final reloaded = BackupLedger(prefs: prefs);
    await reloaded.load();
    expect(reloaded.isBackedUp(file), isTrue);
    expect(reloaded.count, 1);
  });

  test('ledger is isolated per user id', () async {
    final prefs = MemoryPrefsStore();
    final ledger = BackupLedger(prefs: prefs);
    const file = LocalImageFile(
      path: '/photos/x.png',
      name: 'x.png',
      sizeBytes: 42,
    );

    await ledger.load(userId: 1);
    await ledger.markUploaded(file, imageUuid: 'u1');
    expect(ledger.isBackedUp(file), isTrue);

    await ledger.load(userId: 2);
    expect(ledger.isBackedUp(file), isFalse);
    expect(ledger.count, 0);

    await ledger.load(userId: 1);
    expect(ledger.isBackedUp(file), isTrue);
  });

  test('legacy unscoped ledger migrates to the first user', () async {
    final prefs = MemoryPrefsStore();
    final previous = BackupLedger(prefs: prefs);
    const file = LocalImageFile(
      path: '/photos/old.png',
      name: 'old.png',
      sizeBytes: 8,
    );
    await previous.markUploaded(file, imageUuid: 'legacy');

    final next = BackupLedger(prefs: prefs);
    await next.load(userId: 7);
    expect(next.isBackedUp(file), isTrue);
    expect(await prefs.getString(kBackupLedgerKey), isNull);

    await next.load(userId: 8);
    expect(next.isBackedUp(file), isFalse);
  });

  test('deferred uploads stay in memory and hit prefs once on flush', () async {
    final prefs = _CountingPrefs();
    final ledger = BackupLedger(prefs: prefs);
    const a = LocalImageFile(path: '/p/a.jpg', name: 'a.jpg', sizeBytes: 1);
    const b = LocalImageFile(path: '/p/b.jpg', name: 'b.jpg', sizeBytes: 2);

    await ledger.markUploaded(a, imageUuid: 'uuid-a', persist: false);
    await ledger.markUploaded(b, imageUuid: 'uuid-b', persist: false);

    expect(ledger.isBackedUp(a), isTrue);
    expect(ledger.isBackedUp(b), isTrue);
    expect(prefs.writes, 0);

    final beforeFlush = BackupLedger(prefs: prefs.inner);
    await beforeFlush.load();
    expect(beforeFlush.count, 0);

    await ledger.flush();
    expect(prefs.writes, 1);
    await ledger.flush();
    expect(prefs.writes, 1);

    final reloaded = BackupLedger(prefs: prefs.inner);
    await reloaded.load();
    expect(reloaded.isBackedUp(a), isTrue);
    expect(reloaded.isBackedUp(b), isTrue);
    expect(reloaded.entries[fingerprintFor(a)]?.imageUuid, 'uuid-a');
  });

  test('deferred removal is applied on flush', () async {
    final prefs = _CountingPrefs();
    final ledger = BackupLedger(prefs: prefs);
    const file = LocalImageFile(path: '/p/a.jpg', name: 'a.jpg', sizeBytes: 1);
    await ledger.markUploaded(file, imageUuid: 'uuid-a');
    expect(prefs.writes, 1);

    await ledger.removeFingerprint(fingerprintFor(file), persist: false);
    expect(ledger.isBackedUp(file), isFalse);
    expect(prefs.writes, 1);

    await ledger.flush();
    expect(prefs.writes, 2);

    final reloaded = BackupLedger(prefs: prefs.inner);
    await reloaded.load();
    expect(reloaded.isBackedUp(file), isFalse);
  });
}
