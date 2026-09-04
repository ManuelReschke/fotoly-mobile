# Full Sync — Design Spec

**Date:** 2026-08-08  
**Status:** Approved for planning  
**App:** fotoly_mobile (Flutter)

## Problem

The local backup ledger marks images as “already uploaded” after a successful upload. If a user deletes images on Pixelfox (or they are otherwise missing remotely), the app still skips them forever because it only checks the local ledger.

Users need a deliberate way to re-verify remote presence and drop stale “secured” ledger entries so the next normal backup can re-upload those files.

## Goals

- Add a **Full Sync** control under **Settings**.
- Verify ledger entries that have an `imageUuid` against the Pixelfox API.
- If an image is **not present** on Pixelfox, **remove** that ledger entry only.
- **Do not** auto-upload during Full Sync; the next `startBackup()` run handles re-upload.
- Require **double confirmation** before starting.
- Entries **without** `imageUuid` stay untouched (not verifiable with current API data).
- DE + EN copy via existing `lib/l10n/` pattern.
- Unit-testable with fake HTTP (no real API).

## Non-goals

- Bulk remote listing / album inventory APIs.
- Automatic re-upload as part of Full Sync.
- Clearing the entire ledger blindly.
- Verifying entries that lack `imageUuid` (leave as secured).
- Parallel API hammering / rate-limit negotiation beyond simple sequential checks.
- Changing backup queue semantics (`original_only`, session-per-image).

## Product decisions (locked)

| Topic | Decision |
|-------|----------|
| Missing remote image | Remove ledger entry only |
| No `imageUuid` | Leave entry alone |
| After sync | `refreshInventory()` so Home pending/secured counts update |
| Confirmation | Two sequential dialogs (explain → final start) |
| Placement | Settings screen |

## Architecture

```
Settings UI
  → double confirm dialogs
  → BackupService.fullSyncRemote()
       → for each ledger entry with imageUuid:
            PixelfoxApiClient.imageExists(uuid)
            if missing → BackupLedger.removeFingerprint(...)
       → refreshInventory()
  → snack / progress UI
```

### Components

#### 1. `PixelfoxApiClient`

Add a method that checks remote image presence:

- **Request:** `GET {apiRoot}/images/{uuid}` (already defined as `ApiConfig.imageUrl`)
- **200:** exists → return `true` (body may be ignored for presence)
- **404:** missing → return `false`
- **401/403:** throw `PixelfoxApiException` (invalid key / auth) — **do not** remove ledger entries for the run after this (abort or stop with error)
- **Other non-2xx / network:** throw or surface as check error for that item — **do not** remove the entry

Prefer a small result type if useful for tests, e.g. boolean `imageExists` with exceptions for hard failures. Sequential callers decide whether to abort the whole run on first hard auth error (recommended: **abort whole Full Sync on 401/403**; on transient errors **count as error and continue**).

#### 2. `BackupLedger`

Reuse existing APIs:

- `entries` / iteration
- `removeFingerprint(String fingerprint)`
- Optional thin helpers only if they keep call sites clear (e.g. list of entries with non-null uuid). Avoid drive-by refactors.

#### 3. `BackupService`

Add `Future<FullSyncResult> fullSyncRemote()` (name may vary slightly):

**Preconditions**

- Not while `_running` (backup in progress) → return/throw busy
- Optionally not while another full sync is in progress
- Client available via `_clientProvider()`

**Algorithm**

1. Set a `fullSync` / progress state (`checked`, `total`, `removed`, `errors`, `skippedNoUuid`, optional `currentUuid`) and `notifyListeners`.
2. Snapshot ledger entries.
3. For each entry:
   - If `imageUuid == null` or empty → `skippedNoUuid++`
   - Else call `imageExists(uuid)`
     - `false` → `removeFingerprint` + `removed++`
     - `true` → ok
     - check failure → `errors++` (keep entry)
   - Auth failure → stop remaining checks, record error, break
4. Clear progress / running flag.
5. Always attempt `refreshInventory()` at the end (even partial success) so UI counts match ledger.
6. Return a small immutable `FullSyncResult`:

```dart
// conceptual
class FullSyncResult {
  final int checked;        // entries that had a UUID and were attempted
  final int stillPresent;
  final int removed;
  final int skippedNoUuid;
  final int errors;
  final bool abortedAuth;
}
```

**Mutual exclusion**

- `startBackup` should refuse or wait if full sync is running (simple: if full sync in progress, return early / no-op with message).
- `fullSyncRemote` should refuse if backup is running.
- Inventory auto-scan can continue independently; full sync only mutates ledger + then refreshes inventory.

#### 4. Settings UI

Location: `SettingsScreen`, after folder/language cards, **before** logout (or a dedicated “Maintenance” card above logout).

**Control**

- Outlined or filled tonal button: **Full Sync** / **Vollständiger Abgleich**
- Short subtitle explaining: checks remote presence; missing images will be re-queued on next backup
- Disabled when: backup running, full sync running, or not authenticated

**Double confirmation**

1. **Dialog 1 — Explain**  
   Title: Full Sync  
   Body: Checks every locally secured image that has a Pixelfox ID. Images deleted on Pixelfox are removed from the local “already uploaded” list so the next backup can upload them again. No files are uploaded during this step.  
   Actions: Cancel · Continue

2. **Dialog 2 — Confirm**  
   Title: Start Full Sync?  
   Body: This may take a while if many photos are secured. Continue?  
   Actions: Cancel · Start check (primary)

Both cancel paths do nothing.

**Progress**

- Non-dismissible progress dialog or inline indicator while running: “Checking… N / M” (optional detail).
- On completion, dismiss progress and show a snackbar with counts (present / removed / skipped / errors).
- On auth abort, clear error snack.

#### 5. Localization

Add strings to `AppStrings` + DE/EN implementations, for example:

- `fullSyncTitle`, `fullSyncSubtitle`, `fullSyncButton`
- `fullSyncConfirm1Title`, `fullSyncConfirm1Body`, `fullSyncConfirm1Continue`
- `fullSyncConfirm2Title`, `fullSyncConfirm2Body`, `fullSyncConfirm2Start`
- `fullSyncCancel`
- `fullSyncProgress(checked, total)`
- `fullSyncResultSnack(...)` / multi-part helpers
- `fullSyncBusyBackup`, `fullSyncNothingToCheck`, `fullSyncFailed`

No hard-coded user-facing English-only strings in the screen.

## Data / API details

- Ledger identity remains `path::sizeBytes` (`backupFingerprint`).
- `imageUuid` is stored when uploads succeed (`markUploaded(..., imageUuid: result.imageUuid)`).
- Presence check: `GET /api/v1/images/{uuid}` with `X-API-Key` (same as profile/albums).
- `GET /images/{uuid}/status` is **not** required for presence; resource GET is enough (404 = gone). Status endpoint remains unused for this feature.

## Error handling

| Situation | Behavior |
|-----------|----------|
| 404 | Remove ledger entry |
| 200 | Keep entry |
| Network / 5xx / parse error on one image | Count error; keep entry; continue |
| 401/403 | Abort remaining; keep all remaining entries; surface auth error |
| Empty ledger | Snack “nothing to check”; no dialog progress needed after confirms (or short-circuit before dialogs if preferred — either is fine; prefer short-circuit **after** confirms only if counts shown, or **before** second dialog if zero verifiable — simplest: run algorithm and report zeros) |
| Backup running | Button disabled + optional snack if invoked |

## Testing

1. **`PixelfoxApiClient` / fake HTTP**  
   - Extend `FakeApiHttp` to respond to `GET .../images/{uuid}` (map uuid → status or default 404/200).  
   - Assert `imageExists` true/false/exception.

2. **Full sync service logic** (unit test on `BackupService` with fake client + memory ledger):  
   - Mixed: present, missing, no uuid → only missing removed.  
   - Auth failure mid-run → no further removals after abort (entries already removed stay removed).  
   - Does not call upload endpoints.  
   - Invokes inventory refresh path (or observable pending/secured change after scan with scanner stub).

3. **No real network** in unit tests.

## UI sketch (text)

```
[ Settings ]
...
[ Language card ]
...
┌─────────────────────────────┐
│ Full Sync                   │
│ Check that secured photos   │
│ still exist on Pixelfox.    │
│ [  Full Sync  ]             │
└─────────────────────────────┘
[ Log out ]
```

## Implementation notes (for plan)

- Keep screens thin: confirmation + call service + progress/snack.
- Pure logic in services; extend `FakeApiHttp` rather than special-casing production client.
- Follow existing Provider wiring (`BackupService` already has ledger + client provider).
- Run `make check` before claiming done.

## Open points (none blocking)

- Exact snack wording and progress granularity (per-file vs every N) left to implementation polish.
- Card vs plain button styling should match Settings visual language (Folders/Language cards).
