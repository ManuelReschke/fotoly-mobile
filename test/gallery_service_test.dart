import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/models/backup_status.dart';
import 'package:pixelfox_mobile/services/gallery_service.dart';
import 'package:pixelfox_mobile/services/pixelfox_api_client.dart';

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
