import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/backup_status.dart';
import '../models/full_sync_result.dart';
import '../models/upload_result.dart';
import '../models/upload_size_policy.dart';
import 'backup_errors.dart';
import 'backup_ledger.dart';
import 'file_scanner.dart';
import 'pixelfox_api_client.dart';
import 'settings_service.dart';

/// Reads file bytes for upload (injectable).
///
/// Production leaves this unset and streams the file from disk. Tests pass a
/// reader when they do not want a real file.
typedef FileBytesReader = Future<List<int>> Function(String path);

/// Default interval for background inventory polls while the app is open.
const Duration kDefaultAutoScanInterval = Duration(seconds: 30);

/// How many ledger changes to keep in memory before rewriting prefs.
const int kLedgerFlushStride = 25;

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
    this.readBytes,
    this.ledgerFlushStride = kLedgerFlushStride,
    this._autoScanInterval = kDefaultAutoScanInterval,
    this.minAutoInventoryInterval = kMinAutoInventoryInterval,
    this.maxUploadBytes,
    this._planChanges,
    this._serverReachable,
    this._accountUserId,
  }) : _scanner = scanner ?? IoFileScanner() {
    _seenPlanMax = maxUploadBytes?.call();
    _settings.addListener(_onSettingsChanged);
    _planChanges?.addListener(_onPlanChanged);
  }

  final SettingsService _settings;
  final PixelfoxApiClient Function() _clientProvider;
  final BackupLedger _ledger;
  final FileScanner _scanner;
  final FileBytesReader? readBytes;
  final Duration _autoScanInterval;

  /// Current plan cap from the profile. Null means the limit is not known yet.
  final int? Function()? maxUploadBytes;

  final Listenable? _planChanges;

  /// When this returns false, uploads and full sync are refused.
  /// Null means the caller does not track reachability.
  final bool Function()? _serverReachable;

  /// Account whose ledger must be loaded before a scan or upload.
  /// Null leaves the ledger that is already in memory.
  final int? Function()? _accountUserId;

  Future<void> _ensureLedger() => _ledger.ensureUser(_accountUserId?.call());

  int? _seenPlanMax;

  /// Files the server rejected for size while the profile cap was stale or missing.
  final Set<String> _blockedFingerprints = {};
  int? _blockedAtProfileMax;
  int? _serverCeiling;

  /// Ledger prefs rewrite after this many uploads or removals, and always when
  /// a backup or full sync finishes.
  final int ledgerFlushStride;

  /// Minimum gap between quiet/automatic inventory scans.
  final Duration minAutoInventoryInterval;

  // Covers preparation and cleanup as well as the progress shown in the UI.
  bool _jobInProgress = false;
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
  Set<LocalImageFile> _pending = {};
  List<LocalImageFile> _tooLarge = [];
  List<LocalImageFile> _alreadySecured = [];
  int? _classifiedUserId;
  int? _classifiedProfileMax;
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
  int _ledgerOpsSinceFlush = 0;
  bool _inventoryPending = false;
  bool _inventoryPendingQuiet = true;
  bool _inventoryPendingThrottle = true;
  bool _inventoryPendingIncremental = true;

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

  bool get hasImages => _allImages.isNotEmpty;

  /// Images not yet uploaded that still fit the current plan.
  List<LocalImageFile> get pendingImages => List.unmodifiable(_pending);

  /// Images the current plan will not accept. They are not pending.
  List<LocalImageFile> get tooLargeImages => _inPathOrder(_tooLarge);

  /// Images that match a ledger entry (path + size).
  List<LocalImageFile> get alreadySecuredImages =>
      _inPathOrder(_alreadySecured);

  List<LocalImageFile> _inPathOrder(List<LocalImageFile> files) =>
      List.unmodifiable(
        files.toList()..sort((a, b) => a.path.compareTo(b.path)),
      );

  int get pendingCount => _pending.length;
  int get tooLargeCount => _tooLarge.length;
  int get securedCount => _alreadySecured.length;
  HigherUploadPlan? get oversizedUploadPlan =>
      offerForOversizedFiles(_tooLarge).plan;

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
    _planChanges?.removeListener(_onPlanChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // Fire-and-forget rescan when folders change (user-visible).
    unawaited(refreshInventory());
  }

  void _onPlanChanged() {
    final next = maxUploadBytes?.call();
    if (next == _seenPlanMax) return;
    _seenPlanMax = next;
    if (_running) {
      _applyInventory(_allImages);
      notifyListeners();
      return;
    }
    unawaited(refreshInventory(quiet: true, incremental: true));
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
    await refreshInventory(quiet: true, throttle: true, incremental: true);
  }

  /// Exposed for tests — runs one auto-scan cycle without waiting on the timer.
  ///
  /// Defaults match production ([throttle] true, tick counted before the scan).
  @visibleForTesting
  Future<void> autoScanTickForTest({bool throttle = true}) async {
    _autoScanTicks++;
    await refreshInventory(quiet: true, throttle: throttle, incremental: true);
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

  void _mergeInventoryRequest({
    required bool quiet,
    required bool throttle,
    required bool incremental,
  }) {
    _inventoryPending = true;
    // Non-quiet / non-throttled wins so manual refresh and folder changes
    // are not diluted by a concurrent auto-scan request.
    if (!quiet) _inventoryPendingQuiet = false;
    if (!throttle) _inventoryPendingThrottle = false;
    if (!incremental) _inventoryPendingIncremental = false;
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
  /// [incremental] allows reusing directories whose metadata has not changed.
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
    bool incremental = false,
  }) async {
    if (_running) return;

    // Idle + pure throttle short-circuit (no queue work to do).
    if (_activeInventory == null &&
        !_inventoryPending &&
        throttle &&
        shouldThrottleAutoInventory) {
      return;
    }

    _mergeInventoryRequest(
      quiet: quiet,
      throttle: throttle,
      incremental: incremental,
    );

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
      final incremental = _inventoryPendingIncremental;
      _inventoryPending = false;
      _inventoryPendingQuiet = true;
      _inventoryPendingThrottle = true;
      _inventoryPendingIncremental = true;

      if (throttle && shouldThrottleAutoInventory) {
        continue;
      }

      await _performInventoryScan(quiet: quiet, incremental: incremental);
    }
  }

  Future<void> _performInventoryScan({
    required bool quiet,
    required bool incremental,
  }) async {
    _scanInProgress = true;
    _showScanningUi = !quiet;
    if (_showScanningUi) notifyListeners();

    final prevError = _errorMessage;
    final wasLoaded = _inventoryLoaded;
    final wasShowingUi = _showScanningUi;
    var changed = false;
    var succeeded = false;

    try {
      await _ensureLedger();
      final folders = _settings.folders;
      final scanner = _scanner;
      final all = folders.isEmpty && scanner is! IoFileScanner
          ? const <LocalImageFile>[]
          : incremental && scanner is IoFileScanner
          ? await scanner.scanIncrementally(folders)
          : await scanner.scan(folders);
      if (_running) return;

      if (!incremental ||
          scanner is! IoFileScanner ||
          !identical(all, _allImages) ||
          _classifiedUserId != _accountUserId?.call() ||
          _classifiedProfileMax != maxUploadBytes?.call()) {
        final prevPending = _pending;
        final prevTooLarge = _tooLarge;
        final prevSecured = _alreadySecured;
        _applyInventory(all);
        changed =
            !wasShowingUi &&
            (!_sameFiles(prevPending, _pending) ||
                !_sameFiles(prevTooLarge, _tooLarge) ||
                !_sameFiles(prevSecured, _alreadySecured));
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
      // Always notify when we had shown the spinner (to clear it), or when
      // results/errors changed. Pure quiet no-ops stay silent.
      if (wasShowingUi ||
          changed ||
          wasLoaded != _inventoryLoaded ||
          prevError != _errorMessage ||
          _errorMessage != null) {
        notifyListeners();
      }
    }
  }

  String _mapScanError(Object e) {
    if (e is FoldersInaccessibleException) {
      return BackupErrorCodes.foldersInaccessible;
    }
    return BackupErrorCodes.scanFailed;
  }

  bool _sameFiles(
    Iterable<LocalImageFile> before,
    Iterable<LocalImageFile> after,
  ) {
    if (before.length != after.length) return false;
    final previous = before.iterator;
    for (final file in after) {
      previous.moveNext();
      final other = previous.current;
      if (file.path != other.path || file.sizeBytes != other.sizeBytes) {
        return false;
      }
    }
    return true;
  }

  /// Profile cap, tightened by a server rejection until that cap changes.
  int? _effectiveMaxUploadBytes() {
    _releaseIfPlanGrew();
    final profile = maxUploadBytes?.call();
    final server = _serverCeiling;
    if (profile == null || profile <= 0) return server;
    if (server == null || server <= 0) return profile;
    return profile < server ? profile : server;
  }

  void _releaseIfPlanGrew() {
    final profile = maxUploadBytes?.call();
    final blockedAt = _blockedAtProfileMax;
    // A later plan can sit below the snapshot taken at the rejection.
    if (profile != null &&
        profile > 0 &&
        blockedAt != null &&
        profile != blockedAt) {
      _blockedFingerprints.clear();
      _serverCeiling = null;
      _blockedAtProfileMax = null;
      return;
    }
    if (profile == null || profile <= 0 || blockedAt != null) return;
    _blockedFingerprints.removeWhere((fingerprint) {
      final size = _sizeFromFingerprint(fingerprint);
      return size != null && size <= profile;
    });
    // The rejection landed before the profile existed. A higher plan wins.
    final server = _serverCeiling;
    if (server != null && profile > server) {
      _serverCeiling = null;
    }
  }

  int? _sizeFromFingerprint(String fingerprint) {
    final index = fingerprint.lastIndexOf('::');
    if (index < 0) return null;
    return int.tryParse(fingerprint.substring(index + 2));
  }

  void _noteTooLarge(LocalImageFile file, Object error) {
    _blockedFingerprints.add(fingerprintFor(file));
    _blockedAtProfileMax ??= maxUploadBytes?.call();
    final reported = maxBytesFromUploadError(error);
    if (reported != null && reported > 0) {
      final current = _serverCeiling;
      if (current == null || reported < current) {
        _serverCeiling = reported;
      }
    }
  }

  void _applyInventory(List<LocalImageFile> all) {
    _allImages = all;
    _classifiedUserId = _accountUserId?.call();
    _classifiedProfileMax = maxUploadBytes?.call();
    final groups = splitBackupFiles(
      files: all,
      isBackedUp: _ledger.isBackedUp,
      maxUploadBytes: _effectiveMaxUploadBytes(),
      isBlocked: (file) => _blockedFingerprints.contains(fingerprintFor(file)),
    );
    _pending = groups.pending.toSet();
    _tooLarge = groups.tooLarge;
    _alreadySecured = groups.secured;
  }

  Future<void> _noteLedgerChange() async {
    _ledgerOpsSinceFlush++;
    if (ledgerFlushStride <= 1 || _ledgerOpsSinceFlush >= ledgerFlushStride) {
      await _flushLedger();
    }
  }

  Future<void> _flushLedger() async {
    await _ledger.flush();
    _ledgerOpsSinceFlush = 0;
  }

  Future<({UploadResult result, LocalImageFile recorded})> _uploadPendingFile(
    PixelfoxApiClient client,
    LocalImageFile file,
    int? albumId,
  ) async {
    final reader = readBytes;
    if (reader != null) {
      final bytes = await reader(file.path);
      final result = await client.uploadImageBytes(
        filename: file.name,
        bytes: bytes,
        albumId: albumId,
      );
      return (result: result, recorded: file);
    }

    final ioFile = File(file.path);
    final length = await ioFile.length();
    final result = await client.uploadImageStream(
      filename: file.name,
      length: length,
      openRead: () => ioFile.openRead(),
      albumId: albumId,
    );
    final recorded = length == file.sizeBytes
        ? file
        : LocalImageFile(path: file.path, name: file.name, sizeBytes: length);
    return (result: result, recorded: recorded);
  }

  /// Verify ledger entries still exist on Pixelfox; drop missing ones.
  ///
  /// Does **not** upload. Entries without [BackedUpEntry.imageUuid] are left
  /// alone. Missing remote images (HTTP 404) are removed from the ledger so
  /// the next [startBackup] can re-upload them.
  bool get _canReachServer => _serverReachable?.call() ?? true;

  Future<FullSyncResult> fullSyncRemote() async {
    if (_jobInProgress) {
      return FullSyncResult.busyResult;
    }
    if (!_canReachServer) {
      return const FullSyncResult(
        checked: 0,
        stillPresent: 0,
        removed: 0,
        skippedNoUuid: 0,
        errors: 0,
        offline: true,
      );
    }
    _jobInProgress = true;
    try {
      return await _runFullSync();
    } finally {
      _jobInProgress = false;
    }
  }

  Future<FullSyncResult> _runFullSync() async {
    await _ensureLedger();

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
        var removedOne = false;
        try {
          final exists = await client.imageExists(uuid);
          checked++;
          if (exists) {
            stillPresent++;
          } else {
            await _ledger.removeFingerprint(entry.fingerprint, persist: false);
            removedOne = true;
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
        if (removedOne) await _noteLedgerChange();
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
      await _flushLedger();
      await refreshInventory();
      notifyListeners();
    }
  }

  /// Start backup of **pending** images only (skips already secured).
  Future<BackupStatus> startBackup() async {
    if (_jobInProgress) return status;
    if (!_canReachServer) {
      _errorMessage = BackupErrorCodes.offline;
      notifyListeners();
      return status;
    }
    _jobInProgress = true;
    try {
      return await _runBackup();
    } finally {
      _jobInProgress = false;
    }
  }

  Future<BackupStatus> _runBackup() async {
    await _ensureLedger();

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
    _inventoryPendingIncremental = true;

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
      _applyInventory(all);
      final pending = List<LocalImageFile>.of(_pending);
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

        var uploaded = false;
        try {
          final albumId = _settings.albumIdForFile(file.path);
          final uploadedFile = await _uploadPendingFile(client, file, albumId);
          // Ledger identity uses path + the size we uploaded, so the next
          // inventory scan matches and we do not re-upload the same file.
          await _ledger.markUploaded(
            uploadedFile.recorded,
            imageUuid: uploadedFile.result.imageUuid,
            persist: false,
          );
          _completed++;
          uploaded = true;
          // If the size changed on disk, the final scan will reconcile it.
          if (uploadedFile.recorded.sizeBytes == file.sizeBytes &&
              (_pending.remove(file) || _tooLarge.remove(file))) {
            _alreadySecured.add(file);
          }
        } catch (e) {
          if (isUploadTooLargeError(e)) {
            final previousCap = _effectiveMaxUploadBytes();
            _noteTooLarge(file, e);
            if (previousCap != _effectiveMaxUploadBytes()) {
              _applyInventory(_allImages);
            } else if (_blockedFingerprints.contains(fingerprintFor(file)) &&
                _pending.remove(file)) {
              _tooLarge.add(file);
            }
            if (_total > 0) _total--;
          } else {
            _failed++;
            _failedPaths.add(file.path);
          }
        }
        if (uploaded) await _noteLedgerChange();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = _mapScanError(e);
      _running = false;
      return status;
    } finally {
      _running = false;
      _currentFileName = null;
      _currentPath = null;
      await _flushLedger();
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
