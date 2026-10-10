import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/album_error_l10n.dart';
import 'package:fotoly_mobile/l10n/app_strings_en.dart';
import 'package:fotoly_mobile/models/album_sharing.dart';
import 'package:fotoly_mobile/services/album_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';

import 'fake_api_http.dart';

void main() {
  const strings = AppStringsEn();

  PixelfoxApiClient client(FakeApiHttp fake, List<ApiRequestLog> log) {
    return PixelfoxApiClient(apiKey: 'k', httpClient: fake, requestLog: log);
  }

  test('invite by username, then by user id after an ambiguous match', () async {
    final fake = FakeApiHttp(
      memberPostStatus: 409,
      memberPostBody:
          '{"error":"conflict","message":"username matches more than one active user","candidates":[{"user_id":4,"username":"Ada"},{"user_id":9,"username":"Ada"}]}',
    );
    final log = <ApiRequestLog>[];
    final api = client(fake, log);

    await expectLater(
      api.inviteAlbumMember(7, username: 'Ada'),
      throwsA(
        isA<AlbumMemberAmbiguousException>().having(
          (error) => error.candidates.map((item) => item.userId).toList(),
          'candidates',
          [4, 9],
        ),
      ),
    );
    expect(log.single.jsonBody, {'username': 'Ada'});

    fake.memberPostStatus = 201;
    fake.memberPostBody =
        '{"user_id":9,"username":"Ada","role":"viewer","origin":"invite","created_at":"2026-01-01T00:00:00Z","already_member":false}';
    final invited = await api.inviteAlbumMember(7, userId: 9);
    expect(invited.alreadyMember, isFalse);
    expect(invited.member.userId, 9);
    expect(log.last.jsonBody, {'user_id': 9});
  });

  test('remove member accepts an empty 204 body', () async {
    final fake = FakeApiHttp();
    final log = <ApiRequestLog>[];
    await client(fake, log).removeAlbumMember(7, 9);
    expect(log.single.method, 'DELETE');
    expect(log.single.url, endsWith('/albums/7/members/9'));
  });

  test('setCategories sends both id lists and remembers them', () async {
    final fake = FakeApiHttp(
      categoryAssignStatus: 200,
      categoryAssignBody:
          '{"categories":[{"id":2,"name":"Family","slug":"family","scope":"private","album_count":1}]}',
    );
    final log = <ApiRequestLog>[];
    final service = AlbumService(clientProvider: () => client(fake, log));

    expect(service.assignedCategories(7), isNull);
    final saved = await service.setCategories(
      7,
      privateCategoryIds: [2],
      publicCategoryIds: const [],
    );
    expect(saved.single.name, 'Family');
    expect(service.assignedCategories(7)?.single.id, 2);
    expect(log.single.method, 'PUT');
    expect(log.single.jsonBody, {
      'private_category_ids': [2],
      'public_category_ids': <int>[],
    });
  });

  test('category names follow the API charset', () {
    expect(albumCategoryNameIssue('  '), 'required');
    expect(albumCategoryNameIssue('Urlaub 2026'), 'charset');
    expect(albumCategoryNameIssue('a' * 121), 'too_long');
    expect(albumCategoryNameIssue('Family-2026'), isNull);
  });

  test('sharing errors prefer the API message over a generic 404', () {
    String message(String body, {int status = 400}) {
      return localizeAlbumSharingError(
        strings,
        PixelfoxApiException('fallback', statusCode: status, body: body),
        fallback: 'fallback',
      );
    }

    expect(
      message('{"message":"user not found"}', status: 404),
      strings.albumMemberUserNotFound,
    );
    expect(
      message('{"message":"album member limit reached"}', status: 409),
      strings.albumMemberLimit,
    );
    expect(
      message(
        '{"message":"a private category with this name or slug already exists"}',
        status: 409,
      ),
      strings.albumCategoryExists,
    );
  });
}
