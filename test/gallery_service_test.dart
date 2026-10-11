import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/config/app_brand.dart';
import 'package:fotoly_mobile/models/backup_status.dart';
import 'package:fotoly_mobile/services/gallery_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:http/http.dart' as http;

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

  test('refresh without prefs omits sort', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    await service.ensureLoaded();
    expect(service.order, GallerySort.desc);
    expect(fake.sent.single.url.toString(), isNot(contains('sort=')));
  });

  test('oldest refresh requests sort=asc and loadMore keeps it', () async {
    final fake = FakeApiHttp(
      imagesStatus: 200,
      imagesBody:
          '{"items":[{"image_uuid":"old","stable_url":"https://pixelfox.cc/f/old/original/original.jpg"}],"has_more":true,"next_cursor":"c2"}',
    );
    final service = build(fake);
    await service.setOrder(GallerySort.asc);
    expect(fake.sent.single.url.toString(), contains('sort=asc'));
    expect(fake.sent.single.url.toString(), isNot(contains('cursor=')));

    fake.imagesBody =
        '{"items":[{"image_uuid":"older","stable_url":"https://pixelfox.cc/f/older/original/original.jpg"}],"has_more":false}';
    await service.loadMore();
    final more = fake.sent.last.url.toString();
    expect(more, contains('sort=asc'));
    expect(more, contains('cursor=c2'));
    expect(service.items.map((item) => item.imageUuid), ['old', 'older']);
  });

  test('switching from a loaded newest page to oldest replaces items', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    await service.refresh();
    expect(service.items, hasLength(2));

    fake.imagesBody =
        '{"items":[{"image_uuid":"old","stable_url":"https://pixelfox.cc/f/old/original/original.jpg"}],"has_more":false}';
    await service.setOrder(GallerySort.asc);
    expect(service.items.map((item) => item.imageUuid), ['old']);
    final last = fake.sent.last.url.toString();
    expect(last, contains('sort=asc'));
    expect(last, isNot(contains('cursor=')));
  });

  test('setOrder is a no-op when the order is unchanged', () async {
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = build(fake);
    await service.refresh();
    await service.setOrder(GallerySort.desc);
    expect(fake.sent, hasLength(1));
    expect(service.items, hasLength(2));
  });

  test('saved asc is used on the first ensureLoaded', () async {
    final prefs = MemoryPrefsStore();
    await prefs.setString(AppBrand.current.gallerySortPrefsKey, 'asc');
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = GalleryService(
      prefs: prefs,
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await service.ensureLoaded();
    expect(service.order, GallerySort.asc);
    expect(fake.sent, hasLength(1));
    expect(fake.sent.single.url.toString(), contains('sort=asc'));
  });

  test('unknown saved order defaults to newest', () async {
    final prefs = MemoryPrefsStore();
    await prefs.setString(AppBrand.current.gallerySortPrefsKey, 'exif');
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = GalleryService(
      prefs: prefs,
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await service.refresh();
    expect(service.order, GallerySort.desc);
    expect(fake.sent.single.url.toString(), isNot(contains('sort=')));
  });

  test('setOrder persists desc and asc', () async {
    final prefs = MemoryPrefsStore();
    final fake = FakeApiHttp(imagesStatus: 200, imagesBody: imagesFixture);
    final service = GalleryService(
      prefs: prefs,
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await service.setOrder(GallerySort.asc);
    expect(await prefs.getString(AppBrand.current.gallerySortPrefsKey), 'asc');
    await service.setOrder(GallerySort.desc);
    expect(await prefs.getString(AppBrand.current.gallerySortPrefsKey), 'desc');
    final urls = fake.sent.map((request) => request.url.toString()).toList();
    expect(urls.first, contains('sort=asc'));
    expect(urls.last, isNot(contains('sort=')));
  });

  test('a late newest page cannot overwrite an oldest reload', () async {
    final newest = Completer<http.Response>();
    final oldest = Completer<http.Response>();
    final held = _HeldImagesHttp([newest, oldest]);
    final service = GalleryService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: held),
    );

    final first = service.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(service.loading, isTrue);
    expect(held.urls.single.toString(), isNot(contains('sort=')));

    final second = service.setOrder(GallerySort.asc);
    await Future<void>.delayed(Duration.zero);
    expect(service.order, GallerySort.asc);
    expect(service.items, isEmpty);
    expect(service.loaded, isFalse);
    expect(service.loading, isTrue);
    expect(held.urls, hasLength(2));
    expect(held.urls.last.toString(), contains('sort=asc'));

    newest.complete(http.Response(imagesFixture, 200));
    await Future<void>.delayed(Duration.zero);
    expect(service.items, isEmpty);
    expect(service.loading, isTrue);

    oldest.complete(
      http.Response(
        '{"items":[{"image_uuid":"old","stable_url":"https://pixelfox.cc/f/old/original/original.jpg"}],"has_more":false}',
        200,
      ),
    );
    await Future.wait([first, second]);
    expect(service.items.map((item) => item.imageUuid), ['old']);
    expect(service.loading, isFalse);
    expect(service.loaded, isTrue);
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

class _HeldImagesHttp implements ApiHttp {
  _HeldImagesHttp(this._pending);

  final List<Completer<http.Response>> _pending;
  final List<Uri> urls = [];
  var _index = 0;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    urls.add(url);
    return _pending[_index++].future;
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => Future<http.Response>.error(UnimplementedError());

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future<http.StreamedResponse>.error(UnimplementedError());
}
