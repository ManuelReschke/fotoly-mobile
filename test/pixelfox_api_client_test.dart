import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fotoly_mobile/config/api_config.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';

import 'fake_api_http.dart';

void main() {
  late String profileFixture;
  late String sessionFixture;
  late String uploadFixture;
  late String imagesFixture;

  setUpAll(() {
    profileFixture = File(
      'test/fixtures/profile_success.json',
    ).readAsStringSync();
    sessionFixture = File(
      'test/fixtures/upload_session.json',
    ).readAsStringSync();
    uploadFixture = File('test/fixtures/upload_result.json').readAsStringSync();
    imagesFixture = File('test/fixtures/images_list.json').readAsStringSync();
  });

  group('PixelfoxApiClient.getProfile', () {
    test('sends X-API-Key and parses success fixture', () async {
      final fake = FakeApiHttp(profileStatus: 200, profileBody: profileFixture);
      final log = <ApiRequestLog>[];
      final client = PixelfoxApiClient(
        apiKey: 'secret-key-123',
        httpClient: fake,
        requestLog: log,
      );

      final profile = await client.getProfile();

      expect(profile.username, 'pixelpete');
      expect(profile.id, 42);
      expect(profile.plan, 'premium');
      expect(profile.maxUploadBytes, 52428800);

      expect(log, isNotEmpty);
      expect(log.first.method, 'GET');
      expect(log.first.url, contains('/api/v1/user/profile'));
      expect(log.first.headers[ApiConfig.apiKeyHeader], 'secret-key-123');

      final profileReq = fake.sent.whereType<http.BaseRequest>().firstWhere(
        (r) => r.url.path.contains('user/profile'),
      );
      expect(profileReq.headers[ApiConfig.apiKeyHeader], 'secret-key-123');
    });

    test('invalid key surfaces clear error on 401', () async {
      final fake = FakeApiHttp(
        profileStatus: 401,
        profileBody: '{"error":"unauthorized"}',
      );
      final client = PixelfoxApiClient(apiKey: 'bad-key', httpClient: fake);

      expect(
        () => client.getProfile(),
        throwsA(
          isA<PixelfoxApiException>().having(
            (e) => e.message,
            'message',
            contains('Invalid API key'),
          ),
        ),
      );
    });
  });

  group('PixelfoxApiClient auth login', () {
    test('loginWithPassword posts email and returns session token', () async {
      final sessionFixture = File(
        'test/fixtures/auth_session.json',
      ).readAsStringSync();
      final fake = FakeApiHttp(loginStatus: 200, loginBody: sessionFixture);
      final client = PixelfoxApiClient(httpClient: fake);

      final session = await client.loginWithPassword(
        email: 'pete@example.com',
        password: 'secret12',
      );

      expect(session.token, 'pxls_testtoken');
      expect(session.user.username, 'pixelpete');
      final loginReq = fake.sent.whereType<http.BaseRequest>().firstWhere(
        (r) => r.url.path.contains('/auth/login'),
      );
      expect(loginReq.method, 'POST');
    });
  });

  group('PixelfoxApiClient auth register', () {
    test('register posts credentials and returns email from 201', () async {
      final fake = FakeApiHttp(
        registerStatus: 201,
        registerBody:
            '{"email":"pete@example.com","message":"Registration successful. Please check your inbox for the activation link."}',
      );
      final client = PixelfoxApiClient(httpClient: fake);

      final email = await client.register(
        username: 'pete',
        email: 'pete@example.com',
        password: 'secret12',
      );

      expect(email, 'pete@example.com');
      final req = fake.sent.whereType<http.BaseRequest>().firstWhere(
        (r) => r.url.path.contains('/auth/register'),
      );
      expect(req.method, 'POST');
    });

    test('register throws PixelfoxApiException on 409', () async {
      final fake = FakeApiHttp(
        registerStatus: 409,
        registerBody:
            '{"error":"conflict","message":"Email is already registered"}',
      );
      final client = PixelfoxApiClient(httpClient: fake);

      expect(
        () => client.register(
          username: 'pete',
          email: 'pete@example.com',
          password: 'secret12',
        ),
        throwsA(
          isA<PixelfoxApiException>().having(
            (e) => e.message,
            'message',
            'Email is already registered',
          ),
        ),
      );
    });
  });

  group('PixelfoxApiClient upload flow', () {
    test(
      'createUploadSession posts file_size + original_only processing',
      () async {
        final fake = FakeApiHttp(
          sessionStatus: 200,
          sessionBody: sessionFixture,
        );
        final log = <ApiRequestLog>[];
        final client = PixelfoxApiClient(
          apiKey: 'k',
          httpClient: fake,
          requestLog: log,
        );

        const fileSize = 1837421;
        final session = await client.createUploadSession(fileSize: fileSize);

        expect(session.uploadUrl, 'https://pixelfox.cc/api/v1/upload');
        expect(session.token, 'test-session-token-abc123');
        expect(session.maxBytes, 52428800);

        final sessionLog = log.singleWhere(
          (e) => e.method == 'POST' && e.jsonBody != null,
        );
        expect(sessionLog.jsonBody!['file_size'], fileSize);
        expect(sessionLog.jsonBody!['processing'], {
          'profile': 'original_only',
        });
        expect(sessionLog.headers[ApiConfig.apiKeyHeader], 'k');
        expect(sessionLog.headers['Content-Type'], 'application/json');
        expect(
          jsonEncode(sessionLog.jsonBody),
          jsonEncode({
            'file_size': fileSize,
            'processing': {'profile': 'original_only'},
          }),
        );
      },
    );

    test('listAlbums parses fixture list', () async {
      final fake = FakeApiHttp(
        albumsStatus: 200,
        albumsBody:
            '{"albums":[{"id":19,"title":"test","image_count":0,"is_public":false,"is_nsfw":false}]}',
      );
      final client = PixelfoxApiClient(apiKey: 'k', httpClient: fake);
      final albums = await client.listAlbums();
      expect(albums, hasLength(1));
      expect(albums.single.id, 19);
      expect(albums.single.title, 'test');
    });

    test('uploadImageBytes forwards album_id into session body', () async {
      final fake = FakeApiHttp(
        sessionStatus: 200,
        sessionBody: sessionFixture,
        uploadStatus: 200,
        uploadBody: uploadFixture,
      );
      final log = <ApiRequestLog>[];
      final client = PixelfoxApiClient(
        apiKey: 'k',
        httpClient: fake,
        requestLog: log,
      );
      await client.uploadImageBytes(
        filename: 'a.jpg',
        bytes: [1, 2, 3],
        albumId: 19,
      );
      final sessionLog = log.firstWhere((e) => e.jsonBody != null);
      expect(sessionLog.jsonBody!['album_id'], 19);
      expect(sessionLog.jsonBody!['file_size'], 3);
    });

    test(
      'uploadFile sends Bearer session token and multipart filename/bytes',
      () async {
        final fake = FakeApiHttp(
          sessionStatus: 200,
          sessionBody: sessionFixture,
          uploadStatus: 200,
          uploadBody: uploadFixture,
        );
        final log = <ApiRequestLog>[];
        final client = PixelfoxApiClient(
          apiKey: 'k',
          httpClient: fake,
          requestLog: log,
        );

        final bytes = List<int>.generate(64, (i) => i % 256);
        final result = await client.uploadImageBytes(
          filename: 'holiday.jpg',
          bytes: bytes,
        );

        expect(result.imageUuid, 'fd6b0a44-c4bb-4c95-8f48-31d5ec9cc4d8');
        expect(result.duplicate, isFalse);

        final sessionLog = log.firstWhere(
          (e) => e.jsonBody != null && e.jsonBody!.containsKey('file_size'),
        );
        expect(sessionLog.jsonBody!['file_size'], bytes.length);

        final uploadLog = log.firstWhere((e) => e.multipartFilename != null);
        expect(uploadLog.multipartFilename, 'holiday.jpg');
        expect(uploadLog.multipartByteLength, bytes.length);
        expect(
          uploadLog.headers['Authorization'],
          'Bearer test-session-token-abc123',
        );
        expect(uploadLog.url, 'https://pixelfox.cc/api/v1/upload');

        final multipart = fake.sent.whereType<http.MultipartRequest>().single;
        expect(
          multipart.headers['Authorization'],
          'Bearer test-session-token-abc123',
        );
        expect(multipart.files.single.filename, 'holiday.jpg');
        expect(multipart.files.single.length, bytes.length);
      },
    );
  });

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
      expect(() => client.listImages(), throwsA(isA<PixelfoxApiException>()));
    });
  });

  group('PixelfoxApiClient.imageExists', () {
    test('returns true on 200 and false on 404', () async {
      final fake = FakeApiHttp(imageStatusByUuid: {'alive': 200, 'gone': 404});
      final log = <ApiRequestLog>[];
      final client = PixelfoxApiClient(
        apiKey: 'k',
        httpClient: fake,
        requestLog: log,
      );

      expect(await client.imageExists('alive'), isTrue);
      expect(await client.imageExists('gone'), isFalse);

      final urls = log.map((e) => e.url).toList();
      expect(urls.any((u) => u.endsWith('/images/alive')), isTrue);
      expect(urls.any((u) => u.endsWith('/images/gone')), isTrue);
      expect(log.first.headers[ApiConfig.apiKeyHeader], 'k');
    });

    test('throws on 401', () async {
      final fake = FakeApiHttp(imageStatusByUuid: {'x': 401});
      final client = PixelfoxApiClient(apiKey: 'bad', httpClient: fake);

      expect(
        () => client.imageExists('x'),
        throwsA(
          isA<PixelfoxApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('throws on 500 without treating as missing', () async {
      final fake = FakeApiHttp(imageStatusByUuid: {'x': 500});
      final client = PixelfoxApiClient(apiKey: 'k', httpClient: fake);

      expect(
        () => client.imageExists('x'),
        throwsA(isA<PixelfoxApiException>()),
      );
    });
  });
}
