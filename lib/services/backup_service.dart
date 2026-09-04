import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/backup_status.dart';
import '../models/full_sync_result.dart';
import 'backup_errors.dart';
import 'backup_ledger.dart';
import 'file_scanner.dart';
import 'pixelfox_api_client.dart';
import 'settings_service.dart';

/// Reads file bytes for upload (injectable).
typedef FileBytesReader = Future<List<int>> Function(String path);

Future<List<int>> defaultFileBytesReader(String path) =>
    File(path).readAsBytes();

/// Default interval for background inventory polls while the app is open.
const Duration kDefaultAutoScanInterval = Duration(seconds: 30);

/// Skip automatic resume/auto-scan inventory work if a scan finished more
/// recently than this (avoids long freezes when flicking the app away/back).
const Duration kMinAutoInventoryInterval = Duration(seconds: 12);

/// Runs backup jobs: scan selected folders → queue only pending uploads → status.
class BackupService extends ChangeNotifier {
  BackupService({
    required this._settings,
    required this._clientProvider,
    required this._ledger,
    FileScanner? scanner,
    FileBytesReader? readBytes,
    this._autoScanInterval = kDefaultAutoScanInterval,
    this.minAutoInventoryInterval = kMinAutoInventoryInterval,
  }) : _scanner = scanner ?? IoFileScanner(),
       _readBytes = readBytes ?? defaultFileBytesReader {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsService _settings;
  final PixelfoxApiClient Function() _clientProvider;
  final BackupLedger _ledger;
  final FileScanner _scanner;
  final FileBytesReader _readBytes;
  final Duration _autoScanInterval;

  /// Minimum gap between quiet/automatic inventory scans.
  final Duration minAutoInventoryInterval;

  bool _running = false;
  bool _fullSyncRunning = false;
  int _fullSyncChecked = 0;
  int _fullSyncTotal = 0;
  int _completed = 0;
  int _total = 0;
  int _failed = 0;
  String? _currentFileName;
  String? _currentPath;
  String? _errorMessage;
  final List<String> _failedPaths = [];

  List<LocalImageFile> _allImages = [];
  List<LocalImageFile> _pending = [];
  List<LocalImageFile> _alreadySecured = [];
  bool _inventoryLoaded = false;

  /// True while any inventory scan is in flight (including quiet).
  bool _scanInProgress = false;

  /// True only for user-visible scans (manual refresh / first load).
  /// Quiet auto/resume scans must not flip this — otherwise a concurrent
  /// [notifyListeners] (e.g. auto-scan start/stop on lifecycle) shows the
  /// full-screen “Looking for photos…” spinner for the whole slow scan.
  bool _showScanningUi = false;

  Timer? _autoScanTimer;
  bool _autoScanEnabled = false;
  int _autoScanTicks = 0;
  DateTime? _lastInventoryFinishedAt;

  /// Coalesced inventory work: concurrent [refreshInventory] callers merge into
  /// one drain loop so folder-change / manual refresh is not dropped mid-scan.
  Future<void>? _activeInventory;
  bool _inventoryPending = false;
  bool _inventoryPendingQuiet = true;
  bool _inventoryPendingThrottle = true;

  bool get running => _running;

  /// True while [fullSyncRemote] is verifying ledger entries against Pixelfox.
  bool get fullSyncRunning => _fullSyncRunning;

  /// Progress while [fullSyncRunning]: how many UUID checks finished.
  int get fullSyncChecked => _fullSyncChecked;

  /// Progress while [fullSyncRunning]: entries with a UUID to check.
  int get fullSyncTotal => _fullSyncTotal;

  /// UI spinner: only non-quiet inventory work.
  bool get scanning => _showScanningUi;

  /// Whether a scan (quiet or not) is currently running.
  bool get scanInProgress => _scanInProgress || _activeInventory != null;

  bool get inventoryLoaded => _inventoryLoaded;
  bool get autoScanEnabled => _autoScanEnabled;

  /// When the last **successful** inventory scan finished (for throttle tests).
  DateTime? get lastInventoryFinishedAt => _lastInventoryFinishedAt;

  /// How many periodic auto-scan ticks have fired (useful for tests).
  int get autoScanTicks => _autoScanTicks;

  /// All images currently under selected folders.
  List<LocalImageFile> get allImages => List.unmodifiable(_allImages);

  /// Images not yet uploaded (or changed size since last upload).
  List<LocalImageFile> get pendingImages => List.unmodifiable(_pending);

  /// Images that match a ledger entry (path + size).
  List<LocalImageFile> get alreadySecuredImages =>
      List.unmodifiable(_alreadySecured);

  int get pendingCount => _pending.length;
  int get securedCount => _alreadySecured.length;

  BackupStatus get status => deriveBackupStatus(
    running: _running,
    completed: _completed,
    total: _total,
    failed: _failed,
    currentFileName: _currentFileName,
    currentPath: _currentPath,
    errorMessage: _errorMessage,
  );

  List<String> get failedPaths => List.unmodifiable(_failedPaths);

  @override
  void dispose() {
    stopAutoScan();
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Fire-and-forget rescan when folders change (user-visible).
    unawaited(refreshInventory());
  }

  /// Start periodic folder scans while the app is open (default every 30s).
  ///
  /// No-op when already enabled and no explicit [interval] is passed (the
  /// resume path). Passing an [interval] always restarts the timer with that
  /// period — even if it matches the current one.
  void startAutoScan({Duration? interval}) {
    final every = interval ?? _autoScanInterval;
    if (_autoScanEnabled && _autoScanTimer != null && interval == null) {
      return;
    }
    stopAutoScan();
    _autoScanEnabled = true;
    _autoScanTimer = Timer.periodic(every, (_) {
      unawaited(_onAutoScanTick());
    });
    notifyListeners();
  }

  /// Stop periodic scans (e.g. app backgrounded or disposed).
  void stopAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    if (_autoScanEnabled) {
      _autoScanEnabled = false;
      notifyListeners();
    }
  }

  Future<void> _onAutoScanTick() async {
    _autoScanTicks++;
    // Quiet + throttled: no full-screen spinner; skip if busy or recent.
    await refreshInventory(quiet: true, throttle: true);
  }

  /// Exposed for tests — runs one auto-scan cycle without waiting on the timer.
  ///
  /// Defaults match production ([throttle] true, tick counted before the scan).
  @visibleForTesting
  Future<void> autoScanTickForTest({bool throttle = true}) async {
    _autoScanTicks++;
    await refreshInventory(quiet: true, throttle: throttle);
  }

  /// Enumerate only selected folders (testable without uploading).
  Future<List<LocalImageFile>> enumerateSelected() async {
    final folders = _settings.folders;
    if (folders.isEmpty) return [];
    return _scanner.scan(folders);
  }

  /// Whether a quiet/automatic scan should be skipped as too recent.
  ///
  /// Only successful inventory updates the timestamp, so failures do not
  /// suppress automatic retries.
  bool get shouldThrottleAutoInventory {
    final last = _lastInventoryFinishedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < minAutoInventoryInterval;
  }

  void _mergeInventoryRequest({required bool quiet, required bool throttle}) {
    _inventoryPending = true;
    // Non-quiet / non-throttled wins so manual refresh and folder changes
    // are not diluted by a concurrent auto-scan request.
    if (!quiet) _inventoryPendingQuiet = false;
    if (!throttle) _inventoryPendingThrottle = false;
  }

  /// Rescan folders and split into pending vs already secured.
  ///
  /// [quiet] avoids the “Looking for photos…” spinner (used by auto-scan /
  /// resume). Quiet scans also keep [scanning] false for the whole run so a
  /// concurrent lifecycle [notifyListeners] cannot flash the loading hero.
  ///
  /// [throttle] skips work when inventory was refreshed very recently
  /// (resume / auto-scan only — not manual refresh).
  ///
  /// Concurrent callers are coalesced: while a scan is in flight, further
  /// requests merge flags and wait for a drain that always runs the latest
  /// non-throttled / non-quiet need (so folder changes are not dropped).
  ///
  /// On success, clears any previous inventory [status] error so a later grant
  /// or path fix does not leave the UI stuck in [BackupPhase.failed].
  Future<void> refreshInventory({
    bool quiet = false,
    bool throttle = false,
  }) async {
    if (_running) return;

    // Idle + pure throttle short-circuit (no queue work to do).
    if (_activeInventory == null &&
        !_inventoryPending &&
        throttle &&
        shouldThrottleAutoInventory) {
      return;
    }

    _mergeInventoryRequest(quiet: quiet, throttle: throttle);

    while (true) {
      final existing = _activeInventory;
      if (existing != null) {
        await existing;
      } else if (_inventoryPending && !_running) {
        final run = _drainInventoryRequests();
        _activeInventory = run;
        try {
          await run;
        } finally {
          if (identical(_activeInventory, run)) {
            _activeInventory = null;
          }
        }
      } else {
        return;
      }

      if (!_inventoryPending || _running) return;
    }
  }

  Future<void> _drainInventoryRequests() async {
    while (_inventoryPending && !_running) {
      final quiet = _inventoryPendingQuiet;
      final throttle = _inventoryPendingThrottle;
      _inventoryPending = false;
      _inventoryPendingQuiet = true;
      _inventoryPendingThrottle = true;

      if (throttle && shouldThrottleAutoInventory) {
        continue;
      }

      await _performInventoryScan(quiet: quiet);
    }
  }

  Future<void> _performInventoryScan({required bool quiet}) async {
    _scanInProgress = true;
    _showScanningUi = !quiet;
    if (_showScanningUi) notifyListeners();

    final prevPending = _fingerprintList(_pending);
    final prevSecured = _fingerprintList(_alreadySecured);
    final prevError = _errorMessage;
    final wasShowingUi = _showScanningUi;
    var succeeded = false;

    try {
      final folders = _settings.folders;
      if (folders.isEmpty) {
        _allImages = [];
        _pending = [];
        _alreadySecured = [];
      } else {
        final all = await _scanner.scan(folders);
        // Backup may have started while we awaited the scanner — discard.
        if (_running) return;
        _allImages = all;
        _pending = _ledger.pendingOf(all);
        _alreadySecured = _ledger.alreadyOf(all);
      }
      _inventoryLoaded = true;
      // Clear sticky inventory / prior job errors after a successful scan.
      _errorMessage = null;
      succeeded = true;
    } catch (e) {
      if (_running) return;
      _errorMessage = _mapScanError(e);
    } finally {
      _scanInProgress = false;
      _showScanningUi = false;
      // Only successful scans feed the auto/resume throttle so failures
      // can be retried immediately on the next tick or resume.
      if (succeeded) {
        _lastInventoryFinishedAt = DateTime.now();
      }
      final changed =
          prevPending != _fingerprintList(_pending) ||
          prevSecured != _fingerprintList(_alreadySecured) ||
          prevError != _errorMessage;
      // Always notify when we had shown the spinner (to clear it), or when
      // results/errors changed. Pure quiet no-ops stay silent.
      if (wasShowingUi || changed || _errorMessage != null) {
        notifyListeners();
      }
    }
  }

  String _mapScanError(Object e) {
    if (e is FoldersInaccessibleException) {
      return BackupErrorCodes.foldersInaccessible;
    }
    return e.toString();
  }

  String _fingerprintList(List<LocalImageFile> files) =>
      files.map((f) => '${f.path}:${f.sizeBytes}').join('|');

  /// Verify ledger entries still exist on Pixelfox; drop missing ones.
  ///
  /// Does **not** upload. Entries without [BackedUpEntry.imageUuid] are left
  /// alone. Missing remote images (HTTP 404) are removed from the ledger so
  /// the next [startBackup] can re-upload them.
  Future<FullSyncResult> fullSyncRemote() async {
    if (_running || _fullSyncRunning) {
      return FullSyncResult.busyResult;
    }

    _fullSyncRunning = true;
    _fullSyncChecked = 0;
    _fullSyncTotal = 0;
    notifyListeners();

    var checked = 0;
    var stillPresent = 0;
    var removed = 0;
    var skippedNoUuid = 0;
    var errors = 0;
    var abortedAuth = false;

    try {
      final entries = _ledger.entries.values.toList(growable: false);
      final withUuid = entries
          .where((e) => e.imageUuid != null && e.imageUuid!.isNotEmpty)
          .toList(growable: false);
      skippedNoUuid = entries.length - withUuid.length;
      _fullSyncTotal = withUuid.length;
      notifyListeners();

      if (withUuid.isEmpty) {
        return FullSyncResult(
          checked: 0,
          stillPresent: 0,
          removed: 0,
          skippedNoUuid: skippedNoUuid,
          errors: 0,
        );
      }

      final client = _clientProvider();

      for (final entry in withUuid) {
        if (!_fullSyncRunning) break;
        final uuid = entry.imageUuid!;
        try {
          final exists = await client.imageExists(uuid);
          checked++;
          if (exists) {
            stillPresent++;
          } else {
            await _ledger.removeFingerprint(entry.fingerprint);
            removed++;
          }
        } on PixelfoxApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 403) {
            abortedAuth = true;
            errors++;
            break;
          }
          checked++;
          errors++;
        } catch (_) {
          checked++;
          errors++;
        }
        _fullSyncChecked = checked;
        notifyListeners();
      }

      return FullSyncResult(
        checked: checked,
        stillPresent: stillPresent,
        removed: removed,
        skippedNoUuid: skippedNoUuid,
        errors: errors,
        abortedAuth: abortedAuth,
      );
    } finally {
      _fullSyncRunning = false;
      _fullSyncChecked = 0;
      _fullSyncTotal = 0;
      await refreshInventory();
      notifyListeners();
    }
  }

  /// Start backup of **pending** images only (skips already secured).
  Future<BackupStatus> startBackup() async {
    if (_running || _fullSyncRunning) return status;

    // Wait out quiet/manual inventory so we do not double-walk the tree or
    // race writes to _allImages / _pending. Drop leftover auto requests —
    // this method rescans itself and [refreshInventory]s in finally.
    final inFlight = _activeInventory;
    if (inFlight != null) {
      await inFlight;
    }
    _inventoryPending = false;
    _inventoryPendingQuiet = true;
    _inventoryPendingThrottle = true;

    if (_running) return status;

    final folders = _settings.folders;
    if (folders.isEmpty) {
      _errorMessage = BackupErrorCodes.noFolders;
      _running = false;
      notifyListeners();
      return status;
    }

    _running = true;
    _completed = 0;
    _failed = 0;
    _total = 0;
    _currentFileName = null;
    _currentPath = null;
    _errorMessage = null;
    _failedPaths.clear();
    notifyListeners();

    try {
      // Always rescan so new files appear before the run.
      final all = await _scanner.scan(folders);
      _allImages = all;
      final pending = _ledger.pendingOf(all);
      _pending = pending;
      _alreadySecured = _ledger.alreadyOf(all);
      _total = pending.length;
      notifyListeners();

      if (all.isEmpty) {
        _running = false;
        _errorMessage = BackupErrorCodes.noImages;
        notifyListeners();
        return status;
      }

      if (pending.isEmpty) {
        _running = false;
        // Treat as success: nothing left to do.
        _completed = 0;
        _total = 0;
        _errorMessage = null;
        notifyListeners();
        // Keep idle with empty pending — UI shows "all secured".
        return status;
      }

      final client = _clientProvider();

      for (final file in pending) {
        _currentFileName = file.name;
        _currentPath = file.path;
        notifyListeners();

        try {
          final bytes = await _readBytes(file.path);
          final albumId = _settings.albumIdForFile(file.path);
          final result = await client.uploadImageBytes(
            filename: file.name,
            bytes: bytes,
            albumId: albumId,
          );
          // Ledger identity uses the scanned path+size so the next inventory
          // scan matches and we do not re-upload the same file.
          await _ledger.markUploaded(file, imageUuid: result.imageUuid);
          _completed++;
          // Keep pending list roughly in sync for UI mid-run.
          _pending = _ledger.pendingOf(_allImages);
          _alreadySecured = _ledger.alreadyOf(_allImages);
        } catch (e) {
          _failed++;
          _failedPaths.add(file.path);
        }
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = _mapScanError(e);
    } finally {
      _running = false;
      _currentFileName = null;
      _currentPath = null;
      await refreshInventory();
      notifyListeners();
    }

    return status;
  }

  void resetIdle() {
    if (_running) return;
    _completed = 0;
    _total = 0;
    _failed = 0;
    _errorMessage = null;
    _failedPaths.clear();
    notifyListeners();
  }
}
