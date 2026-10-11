import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/models/pixelfox_album.dart';
import 'package:fotoly_mobile/services/album_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';

import 'fake_api_http.dart';

void main() {
  const created = '''
{"id":1,"title":"Alpha","description":"Tage","image_count":0,"is_public":true,"is_nsfw":false,"share_link":"tok","view_url":"/a/tok","image_sort_order":"asc","has_share_password":true}
''';

  PixelfoxApiClient client(FakeApiHttp fake, List<ApiRequestLog> log) {
    return PixelfoxApiClient(apiKey: 'k', httpClient: fake, requestLog: log);
  }

  test('create, update, and delete keep the local list', () async {
    final fake = FakeApiHttp(
      albumsBody: '{"albums":[{"id":2,"title":"Zebra","image_count":3}]}',
      albumWriteBody: created,
      albumWriteStatus: 201,
    );
    final log = <ApiRequestLog>[];
    final service = AlbumService(clientProvider: () => client(fake, log));

    await service.refresh();
    expect(service.albums.single.title, 'Zebra');

    final made = await service.create(
      const AlbumInput(
        title: 'Alpha',
        description: 'Tage',
        isPublic: true,
        imageSortOrder: PixelfoxAlbum.sortOldest,
        sharePassword: 'secret',
      ),
    );
    expect(made.viewUrl, '/a/tok');
    expect(made.isOldestFirst, isTrue);
    expect(service.albums.map((album) => album.title), ['Alpha', 'Zebra']);
    final createLog = log.singleWhere((entry) => entry.method == 'POST');
    expect(createLog.jsonBody!['title'], 'Alpha');
    expect(createLog.jsonBody!['share_password'], 'secret');
    expect(createLog.jsonBody!['image_sort_order'], 'asc');

    fake.albumWriteStatus = 200;
    fake.albumWriteBody =
        '{"id":1,"title":"Alpha 2","description":"Tage","image_count":0,"is_public":true}';
    await service.update(1, const AlbumInput(title: 'Alpha 2'));
    expect(service.byId(1)?.title, 'Alpha 2');

    fake.albumWriteStatus = 204;
    fake.albumWriteBody = '';
    await service.delete(1);
    expect(service.byId(1), isNull);
    expect(service.albums.single.id, 2);
  });

  test('setImageCount updates one album', () async {
    final fake = FakeApiHttp(
      albumsBody: '{"albums":[{"id":4,"title":"Trip","image_count":1}]}',
    );
    final service = AlbumService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await service.refresh();
    service.setImageCount(4, 5);
    expect(service.byId(4)?.imageCount, 5);
  });

  test('refresh and update use the cover from the response', () async {
    final fake = FakeApiHttp(
      albumsBody:
          '{"albums":[{"id":4,"title":"Trip","image_count":1,"cover_image_uuid":"cover-1","cover_stable_url":"https://example/old.jpg"}]}',
      albumWriteStatus: 200,
      albumWriteBody:
          '{"id":4,"title":"Trip 2","image_count":1,"cover_image_uuid":"cover-2","cover_stable_url":"https://example/new.jpg"}',
    );
    final service = AlbumService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await service.refresh();
    expect(service.byId(4)?.coverImageUuid, 'cover-1');
    expect(service.byId(4)?.coverStableUrl, 'https://example/old.jpg');

    await service.update(4, const AlbumInput(title: 'Trip 2'));
    expect(service.byId(4)?.coverImageUuid, 'cover-2');
    expect(service.byId(4)?.coverStableUrl, 'https://example/new.jpg');
    expect(service.byId(4)?.title, 'Trip 2');
  });
}
