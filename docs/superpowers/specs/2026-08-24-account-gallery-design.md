# Account Gallery — Design Spec

**Date:** 2026-08-24  
**Status:** Approved for planning  
**App:** pixelfox_mobile (Flutter)

## Problem

The authenticated app is backup-only: Home shows local-folder scan/upload status, Settings holds folders and appearance. Photos that already live on the Pixelfox account are invisible in the app.

Users want a second primary surface that shows **their account library**: a photo grid, tap for a swipeable fullscreen viewer. Backup stays; it is not replaced.

## Goals

- Bottom navigation with two tabs: **Backup** (today’s Home) and **Gallery**.
- Gallery lists the authenticated user’s images via `GET /api/v1/images` (keyset pagination).
- 3-column square grid; tap opens a fullscreen lightbox; swipe left/right through the same list.
- Read-only: no delete, share, album assignment, or metadata editing.
- Show all account images, including NSFW, with no blur and no filter.
- Persist **image bytes** on disk (Android / iOS / Linux) so the same `stable_url` is not re-downloaded on every visit. Web uses memory + browser HTTP cache.
- Keep the **image list** in memory for the session (tab switches do not refetch). Do not persist the JSON list across process restarts.
- DE + EN copy via existing `lib/l10n/`.
- Unit-testable with `FakeApiHttp`; no real API key.

## Non-goals

- Album-first navigation or album filter chips.
- NSFW blur / hide.
- Pinch-zoom, share sheet, download, delete, or a metadata detail page.
- Persisting the image **list** JSON across app restarts.
- Fetching per-image `GET /api/v1/images/{uuid}` for variant maps.
- Generating local thumbnails from originals (grid decodes a downscaled frame in memory; disk cache stores the downloaded file).
- A new router (`go_router`); keep `MaterialApp` + `IndexedStack`.
- Changing backup queue semantics, auth, or folder picking.
- Wiping the image disk cache on logout.

## Product decisions (locked)

| Topic | Decision |
|-------|----------|
| v1 job | All-account photo grid + swipe lightbox, read-only |
| Navigation | Bottom bar: Backup \| Gallery |
| Settings | AppBar gear on **both** tabs (existing push route) |
| Tab persistence | `IndexedStack` so Backup and Gallery keep widget state |
| NSFW | Show as-is |
| Grid | 3 columns, square tiles, `BoxFit.cover` |
| Viewer | Fullscreen `PageView`, `BoxFit.contain`, close via system Back or tap |
| Pinch-zoom | Not in v1 |
| List API | `GET /api/v1/images?limit=50` + `cursor` |
| List order | Server order (keyset is newest-first) |
| Image URL | Public `stable_url` from the list item (no API key on image GET) |
| Thumbnails | None from API for `original_only` backups; use `stable_url` |
| Byte cache | Disk via `cached_network_image` / `flutter_cache_manager` |
| List cache | In-memory `GalleryService` only |
| Refetch list | First Gallery visit; pull-to-refresh; after **successful** backup **if** the list was already loaded |
| Do not refetch | Tab switch; app resume |
| Page size | 50 (API max 100, default 25) |
| Auth errors | Localized “invalid API key”; do **not** auto-logout |

## Architecture

```
_AuthenticatedShell
  BackupService          (existing)
  GalleryService         (new)
  Scaffold
    body: IndexedStack
      [0] HomeScreen     (backup)
      [1] GalleryScreen
    bottomNavigationBar: Backup | Gallery

PixelfoxApiClient.listImages(limit, cursor)
  → GET /api/v1/images
  → PixelfoxImagePage { items, hasMore, nextCursor }

GalleryService
  items, hasMore, loading / loadingMore / error
  refresh() / loadMore()

Tiles + lightbox
  CachedNetworkImage(stableUrl)   // same cache key
```

`GalleryService` is constructed next to `BackupService` in `_AuthenticatedShell` and provided with `ChangeNotifierProvider`. Screens stay thin.

Image HTTP is **not** the JSON API. `/f/{uuid}/...` URLs are public; the cache manager downloads them directly.

### Components

#### 1. `ApiConfig` + `PixelfoxApiClient.listImages`

Add `imagesUrl()` → `{apiRoot}/images`.

```dart
Future<PixelfoxImagePage> listImages({int limit = 50, String? cursor});
```

Query: `limit` always; `cursor` only when non-null/non-empty. Auth headers same as `listAlbums`. 401/403 → existing invalid-key `PixelfoxApiException`. Other non-200 → “Could not load images”.

Parse:

```json
{
  "items": [ /* PixelfoxImage */ ],
  "has_more": true,
  "next_cursor": "base64url-or-null"
}
```

`next_cursor` may be `null` or omitted when `has_more` is false.

#### 2. `PixelfoxImage` + `PixelfoxImagePage`

New file: `lib/models/pixelfox_image.dart`.

From a list item, require `image_uuid` and `stable_url`. Optional: `title`, `file_name`, `width`, `height`, `created_at`, `is_nsfw` (stored but unused in v1 UI). Skip or drop items missing uuid or `stable_url` rather than failing the whole page.

`PixelfoxImagePage`: `items`, `hasMore`, `nextCursor`.

#### 3. `GalleryService`

New file: `lib/services/gallery_service.dart`. `ChangeNotifier`, same client-provider pattern as `BackupService` (`() => auth.client`).

State:

- `List<PixelfoxImage> items`
- `bool hasMore`
- `String? nextCursor`
- `bool get loaded` — at least one successful fetch this session
- `bool loading` — first page or full refresh
- `bool loadingMore`
- `String? error` — first-page failure only (load-more errors are not sticky)

Rules:

- `refresh()`: replace `items` only after a successful response. On failure of a refresh that already had items, keep the old list and expose the error via a one-shot / `refreshError` the screen can snackbar (do not blank the grid).
- First load failure: `items` stays empty, `error` set, `loaded` false.
- `loadMore()`: no-op if `!hasMore`, `loading`, or `loadingMore`. Append on success. On failure, leave `items` unchanged; screen shows a snackbar.
- Concurrent `refresh`/`loadMore`: ignore the later call while one is in flight.
- After successful backup: shell calls `gallery.refresh()` **only if** `loaded` (never prefetch the gallery just because backup finished).

Dispose with the shell (logout / process end). Disk image cache is **not** cleared.

#### 4. Image disk cache

Dependencies: `cached_network_image` and its `flutter_cache_manager`.

- Cache key = `stable_url`.
- Grid and lightbox share the manager so a tile hit serves the viewer.
- Grid: `BoxFit.cover` plus `memCacheWidth` / `memCacheHeight` sized for a tile (decode smaller than the original; disk still holds the downloaded file).
- Lightbox: `BoxFit.contain`, no extra download if the file is already cached.
- Stale period: 30 days (stable Pixelfox `/f/{uuid}/...` URLs).
- Max objects: 500. Eviction is LRU via the cache manager; no settings UI.
- Web: package memory/browser cache; no `path_provider` disk store. Document in README as “full disk cache on Android / iOS / Linux”.
- Failed URL: tile/viewer placeholder; do not crash the grid. A later **list** refresh may retry the image request.

Do not add a custom thumbnail encoder in v1. `original_only` backups have no small derivatives; caching the original is accepted.

#### 5. App shell + navigation

`_AuthenticatedShellState.build`:

- Provide `BackupService` and `GalleryService`.
- `Scaffold` with `IndexedStack` (two children) and Material 3 `NavigationBar`.
- Destinations: Backup (`Icons.cloud_upload_outlined` + `navBackup`), Gallery (`Icons.photo_library_outlined` + `navGallery`).
- Selected index in shell state. Switching tabs does **not** call `refresh()` or `refreshInventory()`.
- Backup tab keeps current `HomeScreen` AppBar (scan refresh + settings).
- Gallery tab AppBar: brand title (`galleryTitle`), refresh (calls `GalleryService.refresh()` when not loading), settings (same push as Home).
- Nested Scaffolds are OK: each tab owns its AppBar; the shell owns the bottom bar.

Listen to `BackupService`: when `status.phase` becomes `BackupPhase.success` after `working`, if `gallery.loaded` then `unawaited(gallery.refresh())`. Do not refresh on `failed` or `idle`.

#### 6. `GalleryScreen`

New file: `lib/screens/gallery_screen.dart`.

- First visit (`!loaded && loading`): centered spinner.
- `!loaded && error`: localized error + Retry (`refresh()`).
- `loaded && items.isEmpty`: empty copy (no images on the account yet; mention the Backup tab).
- Else: `GridView.builder` (3 columns, small gap, square extent via `SliverGridDelegateWithFixedCrossAxisCount`).
- Pull-to-refresh always when the grid or empty/error body is showing.
- Infinite scroll: when the builder approaches the last items (`index >= items.length - 8`) and `hasMore`, call `loadMore()`. Footer spinner while `loadingMore`.
- Tile: `CachedNetworkImage`; placeholder = muted surface; error = broken-image icon. Tapping a tile with a valid `stableUrl` opens the viewer at that index.

#### 7. `GalleryViewer`

New file: `lib/screens/gallery_viewer.dart` (or `lib/widgets/gallery_viewer.dart` if it is a route-only page).

- `Navigator.push` from the grid (not a dialog) so Android/iOS Back pops it.
- Dark scaffold, no bottom nav (fullscreen route).
- `PageView.builder` over `GalleryService.items` (watch the service so `loadMore` can extend pages).
- Initial page = tapped index.
- Tap on the image (not a swipe) pops the route. System Back pops too.
- Near the last page, trigger `loadMore()` if `hasMore`.
- Image error: placeholder in that page; adjacent swipes still work.

#### 8. l10n

Add to `AppStrings` + DE + EN (no hardcoded English-only UI):

- `navBackup` / `navGallery`
- `galleryTitle`
- `galleryEmptyTitle` / `galleryEmptyBody`
- `galleryLoadError`
- `retry` (dedicated; do not reuse `reset`)
- `galleryRefreshTooltip`
- `galleryImageLoadError` (tile/viewer)

Invalid API key can reuse the existing client/auth wording already shown elsewhere.

## Data flow

1. User logs in → shell boots `BackupService` (existing auto-scan) and `GalleryService` (idle, no fetch yet).
2. User opens Gallery tab → if `!loaded && !loading`, `refresh()` → `GET /api/v1/images?limit=50`.
3. Tiles request `stable_url`. Cache miss → download → disk (native). Cache hit → file, no network.
4. Scroll near end → `GET /api/v1/images?limit=50&cursor=...` → append.
5. Tap tile → viewer `PageView` at index; same cache files.
6. Pull-to-refresh or AppBar refresh → replace list; image cache unchanged (URLs still hit disk).
7. Successful backup while gallery `loaded` → quiet `refresh()` so new uploads appear.
8. Tab away and back → `IndexedStack` + in-memory list; no list HTTP. Images still served from disk cache.
9. Cold start → list fetch once on first Gallery visit; bytes come from disk if the URL was cached in a previous process.

## Error handling

| Situation | Behavior |
|-----------|----------|
| First list load fails (network / 5xx) | Error view + Retry; no tiles |
| 401 / 403 on list | Invalid-key message + Retry; stay logged in |
| Refresh fails but items exist | Keep grid; snackbar |
| `loadMore` fails | Keep items; snackbar; `hasMore` stays true so a later scroll/retry can try again |
| Malformed item (missing uuid/url) | Skip item |
| Single image HTTP/decode fail | Tile/viewer placeholder; rest of gallery fine |
| Empty successful list | Empty state, not an error |
| Cache write fail | Show image from memory/network if possible; no crash |
| Backup still running | Gallery usable; no forced refresh until success |

## Testing

**Fixture:** `test/fixtures/images_list.json` — two items, `has_more`, `next_cursor`. Second fixture or inline JSON for a last page (`has_more: false`).

**`FakeApiHttp`:** handle `GET` path ending `/images` (list) **before** the existing `/images/{uuid}` matcher. Record query `limit` / `cursor`.

**Unit — model:** `PixelfoxImage.fromJson` / page parse; skip incomplete items.

**Unit — client** (`test/pixelfox_api_client_test.dart`):

- sends `X-API-Key`, `/api/v1/images?limit=50`
- passes `cursor` when provided
- maps items + `has_more` + `next_cursor`
- 401 throws `PixelfoxApiException`

**Unit — `GalleryService`** (`test/gallery_service_test.dart`):

- first page fills `items`, `hasMore`
- `loadMore` appends and advances cursor
- `loadMore` no-op when `!hasMore`
- first-load error: empty items + error
- refresh error after success: items retained
- `refresh` after success replaces (does not duplicate) items

**Widget:**

- empty state copy
- error + Retry calls refresh (fake client)
- grid builds N tiles from in-memory items without hitting the network for bytes (stub `stable_url` / avoid real `CachedNetworkImage` IO — inject a test image widget or use `HttpOverrides` / a thin `GalleryImage` wrapper that tests can replace)

Do not unit-test `flutter_cache_manager` disk eviction.

Gate: `make check`.

## Files (expected)

| Path | Change |
|------|--------|
| `pubspec.yaml` | `cached_network_image` |
| `lib/config/api_config.dart` | `imagesUrl()` |
| `lib/models/pixelfox_image.dart` | new |
| `lib/services/pixelfox_api_client.dart` | `listImages` |
| `lib/services/gallery_service.dart` | new |
| `lib/screens/gallery_screen.dart` | new |
| `lib/screens/gallery_viewer.dart` | new |
| `lib/widgets/gallery_image.dart` | thin cached-image wrapper (testable) |
| `lib/app.dart` | shell: both services, IndexedStack, bottom nav, backup→refresh |
| `lib/l10n/app_strings.dart` + `_de` + `_en` | strings |
| `lib/l10n/l10n_test` / `test/l10n_test.dart` | new getters if the suite enumerates them |
| `README.md` | gallery feature + cache note |
| `test/fake_api_http.dart` | list-images route |
| `test/fixtures/images_list.json` | new |
| `test/pixelfox_api_client_test.dart` | listImages cases |
| `test/gallery_service_test.dart` | new |
| `test/widget_test.dart` or `test/gallery_screen_test.dart` | empty / error / grid |

## Success criteria

- Logged-in users switch Backup ↔ Gallery without losing backup status or the already-loaded grid.
- Gallery shows account images from `GET /api/v1/images`, then more on scroll.
- Tap → fullscreen; swipe moves to neighbors; Back returns to the grid.
- Revisiting a tile or the viewer does not re-download a cached `stable_url` on Android / iOS / Linux.
- Tab switches do not fire a new list request.
- Successful backup refreshes an already-loaded gallery.
- Empty, error+retry, and broken-tile states are localized (DE/EN).
- `make check` passes.
