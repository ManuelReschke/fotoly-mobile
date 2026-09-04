import 'dart:convert';

import '../config/app_brand.dart';
import 'file_scanner.dart';
import 'storage.dart';

String get kBackupLedgerKey => AppBrand.current.backupLedgerKey;

String backupLedgerKeyForUser(int? userId) {
  if (userId == null) return kBackupLedgerKey;
  return '${kBackupLedgerKey}_u$userId';
}

/// One successfully uploaded local file (identity = path + size).
class BackedUpEntry {
  const BackedUpEntry({
    required this.path,
    required this.sizeBytes,
    this.imageUuid,
    this.uploadedAtMs,
  });

  final String path;
  final int sizeBytes;
  final String? imageUuid;
  final int? uploadedAtMs;

  Map<String, dynamic> toJson() => {
    'path': path,
    'size_bytes': sizeBytes,
    if (imageUuid != null) 'image_uuid': imageUuid,
    if (uploadedAtMs != null) 'uploaded_at_ms': uploadedAtMs,
  };

  factory BackedUpEntry.fromJson(Map<String, dynamic> json) {
    return BackedUpEntry(
      path: json['path'] as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      imageUuid: json['image_uuid'] as String?,
      uploadedAtMs: json['uploaded_at_ms'] as int?,
    );
  }

  /// Fingerprint used to detect “same file already uploaded”.
  String get fingerprint => backupFingerprint(path, sizeBytes);
}

String backupFingerprint(String path, int sizeBytes) => '$path::$sizeBytes';

String fingerprintFor(LocalImageFile file) =>
    backupFingerprint(file.path, file.sizeBytes);

/// Persists which local images have already been uploaded so we skip them.
class BackupLedger {
  BackupLedger({required this._prefs});

  final PrefsStore _prefs;
  final Map<String, BackedUpEntry> _byFingerprint = {};
  int? _userId;

  Map<String, BackedUpEntry> get entries => Map.unmodifiable(_byFingerprint);

  int get count => _byFingerprint.length;

  bool isBackedUp(LocalImageFile file) =>
      _byFingerprint.containsKey(fingerprintFor(file));

  bool isPathSizeBackedUp(String path, int sizeBytes) =>
      _byFingerprint.containsKey(backupFingerprint(path, sizeBytes));

  Future<void> load({int? userId}) async {
    _userId = userId;
    _byFingerprint.clear();
    var raw = await _prefs.getString(backupLedgerKeyForUser(userId));
    if ((raw == null || raw.isEmpty) && userId != null) {
      raw = await _migrateLegacyLedger(userId);
    }
    if (raw == null || raw.isEmpty) return;
    _ingest(raw);
  }

  Future<String?> _migrateLegacyLedger(int userId) async {
    final legacy = await _prefs.getString(kBackupLedgerKey);
    if (legacy == null || legacy.isEmpty) return null;
    await _prefs.setString(backupLedgerKeyForUser(userId), legacy);
    await _prefs.remove(kBackupLedgerKey);
    return legacy;
  }

  void _ingest(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final entry = BackedUpEntry.fromJson(item);
        _byFingerprint[entry.fingerprint] = entry;
      } else if (item is Map) {
        final entry = BackedUpEntry.fromJson(Map<String, dynamic>.from(item));
        _byFingerprint[entry.fingerprint] = entry;
      }
    }
  }

  Future<void> markUploaded(LocalImageFile file, {String? imageUuid}) async {
    final entry = BackedUpEntry(
      path: file.path,
      sizeBytes: file.sizeBytes,
      imageUuid: imageUuid,
      uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _byFingerprint[entry.fingerprint] = entry;
    await _persist();
  }

  Future<void> removeFingerprint(String fingerprint) async {
    _byFingerprint.remove(fingerprint);
    await _persist();
  }

  Future<void> clear() async {
    _byFingerprint.clear();
    await _prefs.remove(backupLedgerKeyForUser(_userId));
  }

  /// Files that still need uploading (not in ledger with matching size).
  List<LocalImageFile> pendingOf(List<LocalImageFile> all) =>
      all.where((f) => !isBackedUp(f)).toList();

  List<LocalImageFile> alreadyOf(List<LocalImageFile> all) =>
      all.where(isBackedUp).toList();

  Future<void> _persist() async {
    final list = _byFingerprint.values.map((e) => e.toJson()).toList();
    await _prefs.setString(backupLedgerKeyForUser(_userId), jsonEncode(list));
  }
}
