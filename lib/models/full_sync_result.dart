/// Outcome of verifying local ledger entries against Pixelfox.
class FullSyncResult {
  const FullSyncResult({
    required this.checked,
    required this.stillPresent,
    required this.removed,
    required this.skippedNoUuid,
    required this.errors,
    this.abortedAuth = false,
    this.busy = false,
  });

  /// Entries that had an image UUID and were attempted against the API.
  final int checked;

  /// UUID checks that returned present (HTTP 200).
  final int stillPresent;

  /// Ledger entries removed because the remote image was missing (404).
  final int removed;

  /// Ledger entries without an image UUID (left untouched).
  final int skippedNoUuid;

  /// Per-image check failures (network/5xx/etc.) — entry kept.
  final int errors;

  /// Stopped early due to 401/403.
  final bool abortedAuth;

  /// Could not run because backup or another full sync was already running.
  final bool busy;

  static const FullSyncResult empty = FullSyncResult(
    checked: 0,
    stillPresent: 0,
    removed: 0,
    skippedNoUuid: 0,
    errors: 0,
  );

  static const FullSyncResult busyResult = FullSyncResult(
    checked: 0,
    stillPresent: 0,
    removed: 0,
    skippedNoUuid: 0,
    errors: 0,
    busy: true,
  );
}
