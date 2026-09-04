# Account Gallery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Logged-in users get a bottom-nav Gallery tab that shows their Pixelfox account images in a 3-column grid, with a swipeable fullscreen viewer and disk-cached `stable_url` bytes.

**Architecture:** `_AuthenticatedShell` provides `BackupService` + `GalleryService` and an `IndexedStack` (Backup | Gallery). `PixelfoxApiClient.listImages` calls `GET /api/v1/images` with keyset pagination. `GalleryService` holds the session list; `GalleryImage` wraps `CachedNetworkImage` so grid and lightbox share one disk cache. Spec: `docs/superpowers/specs/2026-08-24-account-gallery-design.md`.

**Tech Stack:** Flutter/Dart, Provider, `http`, `cached_network_image` / `flutter_cache_manager`, existing `FakeApiHttp`, manual DE/EN l10n.

## Global Constraints

- User-facing copy via `lib/l10n/` only (DE + EN)
- Extend `PixelfoxApiClient`; URL helpers in `ApiConfig`; no raw HTTP in widgets
- No real API key in tests — `FakeApiHttp` + `test/fixtures/`
- Do not persist the image **list** JSON across process restarts
- Do not auto-logout on 401/403 gallery errors
- Do not wipe the image disk cache on logout
- Do not add album filters, NSFW blur, pinch-zoom, share, delete, or metadata editing
- Page size `limit=50`; image URL is public `stable_url`
- `make check` before claiming done

## Files

- Create: `lib/models/pixelfox_image.dart` — `PixelfoxImage` + `PixelfoxImagePage`
- Create: `test/fixtures/images_list.json`
- Create: `test/pixelfox_image_test.dart`
- Modify: `lib/config/api_config.dart` — `imagesUrl()`
- Modify: `lib/services/pixelfox_api_client.dart` — `listImages`
- Modify: `test/fake_api_http.dart` — `GET /images` list route
- Modify: `test/pixelfox_api_client_test.dart` — `listImages` cases
- Create: `lib/services/gallery_service.dart`
- Create: `test/gallery_service_test.dart`
- Modify: `lib/l10n/app_strings.dart`, `app_strings_de.dart`, `app_strings_en.dart`
- Modify: `test/l10n_test.dart`
- Modify: `pubspec.yaml` — `cached_network_image`
- Create: `lib/widgets/gallery_image.dart` — cache manager + tile/viewer image
- Create: `lib/screens/gallery_screen.dart`
- Create: `lib/screens/gallery_viewer.dart`
- Create: `test/gallery_screen_test.dart`
- Modify: `lib/app.dart` — both services, IndexedStack, NavigationBar, backup→refresh
- Modify: `README.md` — gallery + cache note

---

### Task 1: PixelfoxImage model + list fixture

**Files:**
- Create: `lib/models/pixelfox_image.dart`
- Create: `test/fixtures/images_list.json`
- Test: `test/pixelfox_image_test.dart`

**Interfaces:**
- Consumes: JSON map from `GET /api/v1/images`
- Produces:
  - `class PixelfoxImage` with `imageUuid`, `stableUrl`, `title`, `fileName`, `width`, `height`, `createdAt`, `isNsfw`
  - `static PixelfoxImage? tryParse(Map<String, dynamic> json)` — null if `image_uuid` or `stable_url` missing/blank
  - `factory PixelfoxImage.fromJson(Map<String, dynamic> json)` — throws `FormatException` if `tryParse` is null
  - `class PixelfoxImagePage` with `items`, `hasMore`, `nextCursor`
  - `factory PixelfoxImagePage.fromJson(Map<String, dynamic> json)` — skips incomplete items

- [ ] **Step 1: Write the failing test**

Create `test/fixtures/images_list.json`:

```json
{
  "items": [
    {
      "image_uuid": "fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8",
      "title": "Sunset",
      "file_name": "sunset.jpg",
      "width": 4000,
      "height": 3000,
      "is_nsfw": false,
      "stable_url": "https://pixelfox.cc/f/fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8/original/original.jpg",
      "created_at": "2026-08-20T10:00:00Z"
    },
    {
      "image_uuid": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      "title": "",
      "file_name": "nophoto.jpg",
      "width": 800,
      "height": 600,
      "is_nsfw": true,
      "stable_url": "https://pixelfox.cc/f/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/original/original.jpg",
      "created_at": "2026-08-19T10:00:00Z"
    }
  ],
  "has_more": true,
  "next_cursor": "cursor-page-2"
}
```

Create `test/pixelfox_image_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/models/pixelfox_image.dart';

void main() {
  late Map<String, dynamic> fixture;

  setUpAll(() {
    fixture = jsonDecode(File('test/fixtures/images_list.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('parses list fixture items and page cursor', () {
    final page = PixelfoxImagePage.fromJson(fixture);
    expect(page.items, hasLength(2));
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'cursor-page-2');
    expect(page.items.first.imageUuid, 'fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8');
    expect(page.items.first.title, 'Sunset');
    expect(page.items.first.fileName, 'sunset.jpg');
    expect(page.items.first.width, 4000);
    expect(page.items.first.isNsfw, isFalse);
    expect(page.items.last.isNsfw, isTrue);
    expect(
      page.items.first.stableUrl,
      'https://pixelfox.cc/f/fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8/original/original.jpg',
    );
  });

  test('tryParse returns null without uuid or stable_url', () {
    expect(PixelfoxImage.tryParse({'title': 'x'}), isNull);
    expect(
      PixelfoxImage.tryParse({'image_uuid': 'u', 'stable_url': ''}),
      isNull,
    );
    expect(
      PixelfoxImage.tryParse({
        'image_uuid': 'u',
        'stable_url': 'https://pixelfox.cc/f/u/original/original.jpg',
      }),
      isNotNull,
    );
  });

  test('fromJson page skips incomplete items', () {
    final page = PixelfoxImagePage.fromJson({
      'items': [
        {'title': 'bad'},
        {
          'image_uuid': 'ok',
          'stable_url': 'https://pixelfox.cc/f/ok/original/original.jpg',
        },
      ],
      'has_more': false,
    });
    expect(page.items, hasLength(1));
    expect(page.items.single.imageUuid, 'ok');
    expect(page.hasMore, isFalse);
    expect(page.nextCursor, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pixelfox_image_test.dart`

Expected: FAIL — `pixelfox_image.dart` not found.

- [ ] **Step 3: Write minimal implementation**

`lib/models/pixelfox_image.dart`:

```dart
class PixelfoxImage {
  const PixelfoxImage({
    required this.imageUuid,
    required this.stableUrl,
    this.title = '',
    this.fileName = '',
    this.width,
    this.height,
    this.createdAt,
    this.isNsfw = false,
  });

  final String imageUuid;
  final String stableUrl;
  final String title;
  final String fileName;
  final int? width;
  final int? height;
  final DateTime? createdAt;
  final bool isNsfw;

  static PixelfoxImage? tryParse(Map<String, dynamic> json) {
    final uuid = (json['image_uuid'] as String?)?.trim() ?? '';
    final url = (json['stable_url'] as String?)?.trim() ?? '';
    if (uuid.isEmpty || url.isEmpty) return null;
    DateTime? createdAt;
    final rawCreated = json['created_at'] as String?;
    if (rawCreated != null && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }
    return PixelfoxImage(
      imageUuid: uuid,
      stableUrl: url,
      title: json['title'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
      createdAt: createdAt,
      isNsfw: json['is_nsfw'] as bool? ?? false,
    );
  }

  factory PixelfoxImage.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw FormatException('PixelfoxImage missing image_uuid or stable_url');
    }
    return parsed;
  }
}

class PixelfoxImagePage {
  const PixelfoxImagePage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<PixelfoxImage> items;
  final bool hasMore;
  final String? nextCursor;

  factory PixelfoxImagePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final items = <PixelfoxImage>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final parsed = PixelfoxImage.tryParse(Map<String, dynamic>.from(entry));
      if (parsed != null) items.add(parsed);
    }
    final cursor = json['next_cursor'];
    return PixelfoxImagePage(
      items: items,
      hasMore: json['has_more'] as bool? ?? false,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pixelfox_image_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/pixelfox_image.dart test/fixtures/images_list.json test/pixelfox_image_test.dart
git commit -m "feat(gallery): add PixelfoxImage list model"
```

---

### Task 2: listImages client + FakeApiHttp

**Files:**
- Modify: `lib/config/api_config.dart`
- Modify: `lib/services/pixelfox_api_client.dart`
- Modify: `test/fake_api_http.dart`
- Test: `test/pixelfox_api_client_test.dart`

**Interfaces:**
- Consumes: `PixelfoxImagePage.fromJson`, existing `_authHeaders` / `_log` / `PixelfoxApiException`
- Produces:
  - `ApiConfig.imagesUrl()` → `'$apiRoot/images'`
  - `Future<PixelfoxImagePage> PixelfoxApiClient.listImages({int limit = 50, String? cursor})`
  - `FakeApiHttp` fields `imagesStatus`, `imagesBody`; `GET` path ending `/images` **before** `/images/{uuid}`

- [ ] **Step 1: Extend FakeApiHttp and write failing client tests**

In `test/fake_api_http.dart`:

- Add constructor params `this.imagesStatus = 200`, `this.imagesBody`.
- Store `int imagesStatus` and `String? imagesBody`.
- At the start of `get`, after profile/albums, handle list **before** uuid:

```dart
if (url.path.endsWith('/images')) {
  return http.Response(
    imagesBody ?? '{"items":[],"has_more":false}',
    imagesStatus,
    headers: {'content-type': 'application/json'},
    request: http.Request('GET', url),
  );
}
```

In `test/pixelfox_api_client_test.dart`, add a group (load the list fixture in `setUpAll` like the others):

```dart
group('PixelfoxApiClient.listImages', () {
  test('sends X-API-Key, limit=50, and parses fixture', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final log = <ApiRequestLog>[];
    final client = PixelfoxApiClient(
      apiKey: 'secret-key-123',
      httpClient: fake,
      requestLog: log,
    );

    final page = await client.listImages();

    expect(page.items, hasLength(2));
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'cursor-page-2');
    expect(log.first.method, 'GET');
    expect(log.first.url, contains('/api/v1/images'));
    expect(log.first.url, contains('limit=50'));
    expect(log.first.headers[ApiConfig.apiKeyHeader], 'secret-key-123');
  });

  test('passes cursor query when provided', () async {
    final fake = FakeApiHttp(
      imagesStatus: 200,
      imagesBody: '{"items":[],"has_more":false}',
    );
    final log = <ApiRequestLog>[];
    final client = PixelfoxApiClient(
      apiKey: 'k',
      httpClient: fake,
      requestLog: log,
    );
    await client.listImages(limit: 50, cursor: 'cursor-page-2');
    expect(log.first.url, contains('cursor=cursor-page-2'));
  });

  test('401 throws PixelfoxApiException', () async {
    final fake = FakeApiHttp(
      imagesStatus: 401,
      imagesBody: '{"error":"unauthorized"}',
    );
    final client = PixelfoxApiClient(apiKey: 'bad', httpClient: fake);
    expect(
      () => client.listImages(),
      throwsA(isA<PixelfoxApiException>()),
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pixelfox_api_client_test.dart`

Expected: FAIL — `listImages` not defined.

- [ ] **Step 3: Implement ApiConfig + listImages**

Add to `ApiConfig`:

```dart
static String imagesUrl() => '$apiRoot/images';
```

Add import for `pixelfox_image.dart`. Add method on `PixelfoxApiClient` next to `listAlbums`:

```dart
Future<PixelfoxImagePage> listImages({int limit = 50, String? cursor}) async {
  final uri = Uri.parse('$_apiRoot/images').replace(
    queryParameters: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    },
  );
  _log(ApiRequestLog(method: 'GET', url: uri.toString(), headers: _authHeaders));
  final response = await _http.get(uri, headers: _authHeaders);
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw PixelfoxApiException(
      'Invalid API key — check the key in your Pixelfox settings',
      statusCode: response.statusCode,
      body: response.body,
    );
  }
  if (response.statusCode != 200) {
    throw PixelfoxApiException(
      'Could not load images',
      statusCode: response.statusCode,
      body: response.body,
    );
  }
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return PixelfoxImagePage.fromJson(json);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pixelfox_api_client_test.dart test/pixelfox_image_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/api_config.dart lib/services/pixelfox_api_client.dart test/fake_api_http.dart test/pixelfox_api_client_test.dart
git commit -m "feat(api): list account images with cursor paging"
```

---

### Task 3: GalleryService

**Files:**
- Create: `lib/services/gallery_service.dart`
- Test: `test/gallery_service_test.dart`

**Interfaces:**
- Consumes: `PixelfoxApiClient.listImages({int limit = 50, String? cursor})`, `BackupPhase`
- Produces:
  - `class GalleryService extends ChangeNotifier`
  - `GalleryService({required PixelfoxApiClient Function() clientProvider})`
  - `List<PixelfoxImage> get items`
  - `bool get hasMore`
  - `bool get loaded`
  - `bool get loading`
  - `bool get loadingMore`
  - `String? get error` — sticky first-load failure
  - `String? get snackMessage` — refresh/loadMore failure; UI calls `clearSnack()`
  - `void clearSnack()`
  - `Future<void> refresh()` — full replace on success
  - `Future<void> loadMore()`
  - `Future<void> ensureLoaded()` — no-op if `loaded || loading`
  - `void onBackupPhaseChanged(BackupPhase previous, BackupPhase next)` — `refresh()` only if `previous == working && next == success && loaded`

Rules:

- Concurrent `refresh`/`loadMore`: if either flag is set, return immediately.
- First-load failure: `items` empty, `loaded` false, `error` set.
- Refresh failure after success: keep `items`, set `snackMessage`, do not clear `loaded`.
- `loadMore` no-op when `!hasMore`; on failure keep items, `hasMore` stays true, set `snackMessage`.
- Success clears `error` and `snackMessage`.

- [ ] **Step 1: Write the failing test**

Create `test/gallery_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/models/backup_status.dart';
import 'package:fotoly_mobile/services/gallery_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';

import 'fake_api_http.dart';

void main() {
  late String imagesFixture;

  setUpAll(() {
    imagesFixture = File('test/fixtures/images_list.json').readAsStringSync();
  });

  GalleryService build(FakeApiHttp fake) {
    return GalleryService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
  }

  test('refresh loads first page', () async {
    final service = build(
      FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture),
    );
    await service.refresh();
    expect(service.items, hasLength(2));
    expect(service.hasMore, isTrue);
    expect(service.loaded, isTrue);
    expect(service.error, isNull);
  });

  test('loadMore appends and stops when has_more is false', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    await service.refresh();
    fake.imagesBody =
        '{"items":[{"image_uuid":"third","stable_url":"https://pixelfox.cc/f/third/original/original.jpg"}],"has_more":false}';
    await service.loadMore();
    expect(service.items, hasLength(3));
    expect(service.items.last.imageUuid, 'third');
    expect(service.hasMore, isFalse);
    await service.loadMore();
    expect(service.items, hasLength(3));
  });

  test('first-load error leaves items empty', () async {
    final service = build(
      FakeApiHttp(imagesStatus: 500, imagesBody: '{"error":"x"}'),
    );
    await service.refresh();
    expect(service.items, isEmpty);
    expect(service.loaded, isFalse);
    expect(service.error, isNotNull);
  });

  test('refresh error after success keeps items', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    await service.refresh();
    fake.imagesStatus = 500;
    fake.imagesBody = '{"error":"x"}';
    await service.refresh();
    expect(service.items, hasLength(2));
    expect(service.loaded, isTrue);
    expect(service.snackMessage, isNotNull);
  });

  test('refresh replaces items rather than duplicating', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    await service.refresh();
    await service.refresh();
    expect(service.items, hasLength(2));
  });

  test('ensureLoaded fetches once', () async {
    var fetches = 0;
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final client = PixelfoxApiClient(apiKey: 'k', httpClient: fake);
    final service = GalleryService(
      clientProvider: () {
        fetches++;
        return client;
      },
    );
    await service.ensureLoaded();
    await service.ensureLoaded();
    expect(fetches, 1);
  });

  test('onBackupPhaseChanged refreshes only after success if loaded', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    service.onBackupPhaseChanged(BackupPhase.working, BackupPhase.success);
    expect(service.loaded, isFalse);

    await service.refresh();
    fake.imagesBody =
        '{"items":[{"image_uuid":"new","stable_url":"https://pixelfox.cc/f/new/original/original.jpg"}],"has_more":false}';
    service.onBackupPhaseChanged(BackupPhase.working, BackupPhase.success);
    await Future<void>.delayed(Duration.zero);
    expect(service.items.single.imageUuid, 'new');
  });
}
```

`GalleryService` must call `_clientProvider()` once per `listImages` so the `fetches` counter is accurate.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gallery_service_test.dart`

Expected: FAIL — `gallery_service.dart` not found.

- [ ] **Step 3: Write GalleryService**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/backup_status.dart';
import '../models/pixelfox_image.dart';
import 'pixelfox_api_client.dart';

class GalleryService extends ChangeNotifier {
  GalleryService({required PixelfoxApiClient Function() clientProvider})
    : _clientProvider = clientProvider;

  final PixelfoxApiClient Function() _clientProvider;

  List<PixelfoxImage> _items = [];
  bool _hasMore = false;
  String? _nextCursor;
  bool _loaded = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _snackMessage;

  List<PixelfoxImage> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  String? get snackMessage => _snackMessage;

  void clearSnack() {
    if (_snackMessage == null) return;
    _snackMessage = null;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading || _loadingMore) return;
    _loading = true;
    notifyListeners();
    try {
      final page = await _clientProvider().listImages();
      _items = page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loaded = true;
      _error = null;
      _snackMessage = null;
    } catch (e) {
      final message = e is PixelfoxApiException ? e.message : e.toString();
      if (_loaded) {
        _snackMessage = message;
      } else {
        _error = message;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loading || _loadingMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _clientProvider().listImages(cursor: _nextCursor);
      _items = [..._items, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _snackMessage = null;
    } catch (e) {
      _snackMessage = e is PixelfoxApiException ? e.message : e.toString();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void onBackupPhaseChanged(BackupPhase previous, BackupPhase next) {
    if (previous == BackupPhase.working &&
        next == BackupPhase.success &&
        _loaded) {
      unawaited(refresh());
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gallery_service_test.dart test/pixelfox_api_client_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/gallery_service.dart test/gallery_service_test.dart
git commit -m "feat(gallery): add GalleryService paging and backup refresh hook"
```

---

### Task 4: l10n strings

**Files:**
- Modify: `lib/l10n/app_strings.dart`
- Modify: `lib/l10n/app_strings_de.dart`
- Modify: `lib/l10n/app_strings_en.dart`
- Test: `test/l10n_test.dart`

**Interfaces:**
- Consumes: existing `AppStrings` abstract class
- Produces getters (add under a `// —— Gallery ——` section after chrome):
  - `navBackup`, `navGallery`, `galleryTitle`, `galleryEmptyTitle`, `galleryEmptyBody`, `galleryLoadError`, `retry`, `galleryRefreshTooltip`, `galleryImageLoadError`

Copy (lock these exact strings):

| Getter | DE | EN |
|--------|----|----|
| `navBackup` | Backup | Backup |
| `navGallery` | Galerie | Gallery |
| `galleryTitle` | Galerie | Gallery |
| `galleryEmptyTitle` | Noch keine Bilder | No photos yet |
| `galleryEmptyBody` | Lade Fotos über den Backup-Tab hoch. | Upload photos from the Backup tab. |
| `galleryLoadError` | Bilder konnten nicht geladen werden. | Could not load images. |
| `retry` | Erneut versuchen | Try again |
| `galleryRefreshTooltip` | Galerie aktualisieren | Refresh gallery |
| `galleryImageLoadError` | Bild nicht verfügbar | Image unavailable |

- [ ] **Step 1: Write the failing test**

Append to `test/l10n_test.dart`:

```dart
test('gallery strings exist in DE and EN', () {
  const de = AppStringsDe();
  const en = AppStringsEn();
  expect(de.navGallery, 'Galerie');
  expect(en.navGallery, 'Gallery');
  expect(de.galleryEmptyTitle, 'Noch keine Bilder');
  expect(en.galleryEmptyTitle, 'No photos yet');
  expect(de.retry, 'Erneut versuchen');
  expect(en.retry, 'Try again');
  expect(de.galleryLoadError, contains('nicht geladen'));
  expect(en.galleryImageLoadError, 'Image unavailable');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/l10n_test.dart`

Expected: FAIL — getters missing.

- [ ] **Step 3: Add getters to abstract + DE + EN**

Abstract declarations in `app_strings.dart`. Implementations in `_de` and `_en` with the table above. Do not hardcode these strings in screens later.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/l10n_test.dart`

Expected: PASS (`make analyze` will fail until all `AppStrings` implementations define the new getters — both DE and EN must be updated in this step).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_strings.dart lib/l10n/app_strings_de.dart lib/l10n/app_strings_en.dart test/l10n_test.dart
git commit -m "feat(l10n): add gallery navigation and empty/error copy"
```

---

### Task 5: Cached GalleryImage widget

**Files:**
- Modify: `pubspec.yaml` (add `cached_network_image: ^3.4.1`)
- Create: `lib/widgets/gallery_image.dart`

**Interfaces:**
- Consumes: `cached_network_image`, `flutter_cache_manager`
- Produces:
  - `const String kGalleryCacheKey = 'pixelfoxGallery'`
  - `CacheManager galleryCacheManager()` — `Config(kGalleryCacheKey, stalePeriod: Duration(days: 30), maxNrOfCacheObjects: 500)`. Use a lazy singleton so tests can override via optional `cacheManager` param.
  - `typedef GalleryImageBuilder = Widget Function({required String url, required BoxFit fit, int? memCacheWidth, int? memCacheHeight})`
  - `class GalleryImage extends StatelessWidget`
  - `GalleryImage({required String url, BoxFit fit = BoxFit.cover, int? memCacheWidth, int? memCacheHeight, String? errorLabel, BaseCacheManager? cacheManager})`
  - `CachedNetworkImage` with `cacheManager: cacheManager ?? galleryCacheManager()`, `imageUrl: url`, given `fit` / mem cache sizes, placeholder = `ColoredBox` of `Theme.of(context).colorScheme.surfaceContainerHighest`, error = icon `Icons.broken_image_outlined` + optional `errorLabel`

No network unit test. After `flutter pub get`, `dart analyze lib/widgets/gallery_image.dart` must be clean.

- [ ] **Step 1: Add dependency and widget**

```yaml
  cached_network_image: ^3.4.1
```

under `dependencies:` in `pubspec.yaml`. Run `flutter pub get`.

`lib/widgets/gallery_image.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const String kGalleryCacheKey = 'pixelfoxGallery';

typedef GalleryImageBuilder =
    Widget Function({
      required String url,
      required BoxFit fit,
      int? memCacheWidth,
      int? memCacheHeight,
    });

CacheManager? _galleryCache;

CacheManager galleryCacheManager() {
  return _galleryCache ??= CacheManager(
    Config(
      kGalleryCacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}

class GalleryImage extends StatelessWidget {
  const GalleryImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorLabel,
    this.cacheManager,
  });

  final String url;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? errorLabel;
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      cacheManager: cacheManager ?? galleryCacheManager(),
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) => ColoredBox(color: scheme.surfaceContainerHighest),
      errorWidget: (context, url, error) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
            if (errorLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorLabel!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze the new file**

Run: `flutter analyze lib/widgets/gallery_image.dart`

Expected: no issues. If `BaseCacheManager` vs `CacheManager` types disagree, type `cacheManager` as `CacheManager?` or the type `CachedNetworkImage.cacheManager` expects (check the package API after pub get).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/widgets/gallery_image.dart
git commit -m "feat(gallery): cache stable_url images on disk"
```

---

### Task 6: GalleryScreen + GalleryViewer

**Files:**
- Create: `lib/screens/gallery_screen.dart`
- Create: `lib/screens/gallery_viewer.dart`
- Test: `test/gallery_screen_test.dart`

**Interfaces:**
- Consumes: `GalleryService`, `GalleryImageBuilder`, l10n, `SettingsScreen` push pattern from `HomeScreen` (settings gear), `PixelfoxBrandTitle`
- Produces:
  - `class GalleryScreen extends StatefulWidget` with optional `GalleryImageBuilder? imageBuilder` (tests inject a `ColoredBox`; production uses `GalleryImage`)
  - `class GalleryViewer extends StatelessWidget` — `Navigator.push` target; watches `GalleryService`; `PageView.builder`; `initialIndex`; tap pops; near last index calls `loadMore()`

`GalleryScreen` behavior:

- `initState` / first frame: `context.read<GalleryService>().ensureLoaded()`
- AppBar: `PixelfoxBrandTitle(label: s.galleryTitle)`, refresh (`s.galleryRefreshTooltip`, disabled while `loading || loadingMore`), settings (same `Navigator.push` + `ChangeNotifierProvider<BackupService>.value` as Home — **also provide GalleryService** if settings does not need it; copy Home’s settings push exactly: BackupService only)
- Body states:
  - `!loaded && loading` → centered `CircularProgressIndicator`
  - `!loaded && error != null` → `Text(s.galleryLoadError)` + `FilledButton` `s.retry` → `refresh()`
  - `loaded && items.isEmpty` → `s.galleryEmptyTitle` + `s.galleryEmptyBody`
  - else → `RefreshIndicator` + `GridView.builder` 3 columns, `childAspectRatio: 1`, spacing 2, `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2)`
- Tile: `imageBuilder` or `GalleryImage(url: item.stableUrl, fit: BoxFit.cover, memCacheWidth: (MediaQuery.sizeOf(context).width / 3 * devicePixelRatio).round())`. `GestureDetector`/`InkWell` → `Navigator.push` `GalleryViewer(initialIndex: index)`.
- When `index >= items.length - 8 && hasMore` → `loadMore()`.
- If `loadingMore`, last grid child or a footer spinner is acceptable; prefer checking `loadingMore` after the last item.
- `RefreshIndicator.onRefresh` → `refresh()`.
- When `snackMessage != null`, `addPostFrameCallback` show `SnackBar` then `clearSnack()`.

`GalleryViewer`:

- `Scaffold` background `Colors.black`, no `NavigationBar`.
- `PageView.builder(itemCount: items.length, controller: PageController(initialPage: initialIndex))`.
- Each page: `GestureDetector(onTap: () => Navigator.pop(context), child: imageBuilder/GalleryImage(fit: BoxFit.contain))` — no memCacheWidth so the cached file can decode larger.
- `onPageChanged`: if `index >= items.length - 3` call `loadMore()`.
- Watch `GalleryService` so appended items grow `itemCount`.

- [ ] **Step 1: Write the failing widget tests**

`test/gallery_screen_test.dart` — use `pumpL10n` pattern from `test/widget_test.dart` **plus** `ChangeNotifierProvider<GalleryService>` and a `FakeApiHttp`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/gallery_screen.dart';
import 'package:fotoly_mobile/services/gallery_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

Widget stubImage({
  required String url,
  required BoxFit fit,
  int? memCacheWidth,
  int? memCacheHeight,
}) {
  return ColoredBox(
    color: Colors.grey,
    child: Text(url, maxLines: 1),
  );
}

Future<void> pumpGallery(
  WidgetTester tester, {
  required GalleryService gallery,
}) async {
  final locale = LocaleController(prefs: MemoryPrefsStore());
  await locale.setLocale(AppLocale.en);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<GalleryService>.value(value: gallery),
      ],
      child: MaterialApp(
        home: GalleryScreen(imageBuilder: stubImage),
      ),
    ),
  );
  await tester.pump(); // ensureLoaded starts
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state after successful empty list', (tester) async {
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          imagesStatus: 200,
          imagesBody: '{"items":[],"has_more":false}',
        ),
      ),
    );
    await pumpGallery(tester, gallery: gallery);
    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.text('Upload photos from the Backup tab.'), findsOneWidget);
  });

  testWidgets('error state shows retry', (tester) async {
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          imagesStatus: 500,
          imagesBody: '{"error":"x"}',
        ),
      ),
    );
    await pumpGallery(tester, gallery: gallery);
    expect(find.text('Could not load images.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('grid builds a tile per item', (tester) async {
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          imagesStatus: 200,
          imagesBody:
              '{"items":['
              '{"image_uuid":"a","stable_url":"https://example/a.jpg"},'
              '{"image_uuid":"b","stable_url":"https://example/b.jpg"}'
              '],"has_more":false}',
        ),
      ),
    );
    await pumpGallery(tester, gallery: gallery);
    expect(find.text('https://example/a.jpg'), findsOneWidget);
    expect(find.text('https://example/b.jpg'), findsOneWidget);
  });
}
```

If `pumpAndSettle` times out on an infinite animation, `pump(Duration(milliseconds: 50))` twice instead.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gallery_screen_test.dart`

Expected: FAIL — screens missing.

- [ ] **Step 3: Implement GalleryScreen and GalleryViewer**

Follow the behavior list above. Keep screens thin: no HTTP, only `GalleryService` + `imageBuilder`.

Settings button: if `BackupService` is not provided in the widget test, hide the settings icon when `Provider.of<BackupService>(context, listen: false)` throws — **do not**. Use `context.watch<BackupService?>()` only if registered as optional. Simpler: settings `onPressed` uses `context.read<BackupService>()` like Home. Widget tests must not tap settings. GalleryScreen still **declares** the settings button; tests that pump without BackupService will throw on **build** if it `read`s BackupService at build time. Therefore: only `read<BackupService>()` inside the settings `onPressed` callback, not in `build`. Refresh button only needs `GalleryService`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/gallery_screen_test.dart test/gallery_service_test.dart test/l10n_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gallery_screen.dart lib/screens/gallery_viewer.dart test/gallery_screen_test.dart
git commit -m "feat(gallery): add grid screen and swipe viewer"
```

---

### Task 7: Authenticated shell — bottom nav + backup hook

**Files:**
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `GalleryService`, `GalleryScreen`, `HomeScreen`, `BackupPhase`
- Produces: `_AuthenticatedShell` provides both services; `Scaffold` + `IndexedStack` index 0 Home / 1 Gallery; Material 3 `NavigationBar` with `Icons.cloud_upload_outlined` + `s.navBackup` and `Icons.photo_library_outlined` + `s.navGallery`; tab switch does **not** call `refresh` or `refreshInventory`; listen to `BackupService` and call `gallery.onBackupPhaseChanged(previous, next)` when `backup.status.phase` changes

- [ ] **Step 1: Write a failing widget test for the nav bar**

Add to `test/gallery_screen_test.dart` **or** a small `test/app_shell_test.dart` only if you extract a public widget. `_AuthenticatedShell` is private. Extract:

`lib/widgets/main_shell.dart`:

```dart
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}
```

It assumes `BackupService` + `GalleryService` + `LocaleController` are already provided. Body: `IndexedStack(children: const [HomeScreen(), GalleryScreen()])` + `NavigationBar`.

Track previous backup phase in `didChangeDependencies` / listener:

```dart
BackupPhase _lastPhase = BackupPhase.idle;

void _onBackup() {
  final backup = context.read<BackupService>();
  final gallery = context.read<GalleryService>();
  final next = backup.status.phase;
  if (next != _lastPhase) {
    gallery.onBackupPhaseChanged(_lastPhase, next);
    _lastPhase = next;
  }
}
```

Register the listener in `initState` via `WidgetsBinding.addPostFrameCallback` reading BackupService, or in `didChangeDependencies` once.

Widget test: pump `MainShell` with fake `BackupService` is heavy (Home needs settings, ledger, media). **Do not** instantiate a full `BackupService` scan. Instead test `MainShell` with a **minimal stub only if you introduce an interface** — YAGNI.

Practical test: pump `MainShell` is too coupled. Verify nav labels with a dedicated `GalleryNavBar` widget:

```dart
class GalleryNavBar extends StatelessWidget {
  const GalleryNavBar({
    super.key,
    required this.index,
    required this.onChanged,
  });
  final int index;
  final ValueChanged<int> onChanged;
  // uses context.l10n.navBackup / navGallery
}
```

Test: `pumpL10n` + `GalleryNavBar(index: 0, onChanged: ...)` finds `Backup` and `Gallery`.

Keep this widget in `lib/widgets/gallery_nav_bar.dart` **or** inline in `main_shell.dart` and test by pumping `MainShell` **without** Home’s backup if you wrap Home in a dummy. Simplest path that still tests the bar:

Extract `lib/widgets/main_shell.dart` as specified. For the widget test, do **not** pump `MainShell` if `HomeScreen` requires live `BackupService`. Test only `GalleryNavBar`.

Write `test/gallery_nav_bar_test.dart`:

```dart
testWidgets('nav destinations are localized', (tester) async {
  await pumpL10n(
    tester,
    GalleryNavBar(index: 0, onChanged: (_) {}),
  );
  expect(find.text('Backup'), findsOneWidget);
  expect(find.text('Gallery'), findsOneWidget);
});
```

Copy `pumpL10n` from `widget_test.dart` (duplicate the helper in this file — do not export from widget_test).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gallery_nav_bar_test.dart`

Expected: FAIL — widget missing.

- [ ] **Step 3: Implement MainShell + GalleryNavBar and wire app.dart**

`lib/widgets/gallery_nav_bar.dart` — `NavigationBar` with two `NavigationDestination`s.

`lib/widgets/main_shell.dart` — tab index state, `IndexedStack`, `GalleryNavBar`, backup phase listener calling `gallery.onBackupPhaseChanged`.

`lib/app.dart` `_AuthenticatedShellState.build`:

```dart
return MultiProvider(
  providers: [
    ChangeNotifierProvider<BackupService>.value(value: _backup!),
    ChangeNotifierProvider<GalleryService>.value(value: _gallery!),
  ],
  child: const MainShell(),
);
```

Construct `_gallery` next to `_backup` in `didChangeDependencies`:

```dart
_gallery = GalleryService(
  clientProvider: () {
    final client = auth.client;
    if (client == null) throw StateError('Not authenticated');
    return client;
  },
);
```

Dispose `_gallery` in `dispose`. Do not call `ensureLoaded` from the shell.

- [ ] **Step 4: Run tests**

Run: `flutter test test/gallery_nav_bar_test.dart test/gallery_screen_test.dart test/gallery_service_test.dart`

Expected: PASS. Then `flutter analyze`.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart lib/widgets/main_shell.dart lib/widgets/gallery_nav_bar.dart test/gallery_nav_bar_test.dart
git commit -m "feat(gallery): add Backup/Gallery bottom navigation"
```

---

### Task 8: README + quality gate

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: implemented gallery
- Produces: Features bullet for account gallery; note that Chrome can show the gallery (API + cached URLs); disk cache on Android/iOS/Linux; Web uses memory/browser cache

- [ ] **Step 1: Update README Features and Architecture rows**

Add under Features:

```markdown
- **Gallery** — bottom-nav tab lists account images (`GET /api/v1/images`), swipeable viewer; image files are disk-cached on Android / iOS / Linux (browser cache on Web)
```

Add Architecture row:

```markdown
| `lib/services/gallery_service.dart` | Account image list + cursor paging |
```

In the Chrome/Web paragraph, mention gallery works (auth + network images); folder backup still does not.

- [ ] **Step 2: Run the full gate**

Run: `make check`

Expected: analyze + all tests pass.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document account gallery and image cache"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| Bottom nav Backup \| Gallery, IndexedStack | 7 |
| Settings gear on both tabs | 6 (gallery AppBar), Home unchanged |
| GET /api/v1/images limit 50 + cursor | 2 |
| PixelfoxImage skip incomplete | 1 |
| GalleryService session list, no JSON persist | 3 |
| First visit / pull-to-refresh / AppBar refresh | 3 `ensureLoaded`/`refresh`, 6 UI |
| Refresh after BackupPhase.working→success if loaded | 3 hook + 7 listener |
| No refetch on tab switch / resume | 7 (no calls) |
| 3-col square grid, cover | 6 |
| Lightbox PageView, contain, tap/back close | 6 |
| Disk cache 30d / 500 objects, shared URL | 5 |
| NSFW shown as-is | 6 (no filter) |
| Empty / error+retry / snackbar loadMore | 3 + 6 |
| 401 stay logged in | 2 exception, 6 retry |
| DE/EN l10n | 4 |
| FakeApiHttp tests | 1–3, 6 |
| README | 8 |
| `make check` | 8 |

No album filter, no NSFW blur, no pinch-zoom, no list persistence, no cache wipe on logout — none of these have tasks (correct).
