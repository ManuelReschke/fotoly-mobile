import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/albums_screen.dart';
import 'package:fotoly_mobile/services/album_service.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
import 'package:fotoly_mobile/services/gallery_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

Future<void> pumpAlbums(
  WidgetTester tester, {
  required AlbumService albums,
  required AuthService auth,
  required GalleryService gallery,
}) async {
  final locale = LocaleController(prefs: MemoryPrefsStore());
  await locale.setLocale(AppLocale.en);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<AlbumService>.value(value: albums),
        ChangeNotifierProvider<GalleryService>.value(value: gallery),
        ChangeNotifierProvider<AuthService>.value(value: auth),
      ],
      child: const MaterialApp(home: AlbumsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('invites a member from the album menu', (tester) async {
    final fake = FakeApiHttp(
      profileBody: File(
        'test/fixtures/profile_success.json',
      ).readAsStringSync(),
      albumsBody:
          '{"albums":[{"id":7,"title":"Coast","image_count":0,"is_public":true,"view_url":"/a/coast"}]}',
      membersBody: '{"members":[]}',
      memberPostBody:
          '{"user_id":3,"username":"ada","role":"viewer","origin":"invite","created_at":"2026-01-01T00:00:00Z","already_member":false}',
    );
    final log = <ApiRequestLog>[];
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
        requestLog: log,
      ),
    );
    await auth.loginWithApiKey('k');
    final albums = AlbumService(clientProvider: () => auth.client!);
    final gallery = GalleryService(clientProvider: () => auth.client!);
    await pumpAlbums(tester, albums: albums, auth: auth, gallery: gallery);

    await tester.tap(find.text('Coast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Album actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('album-action-members')));
    await tester.pumpAndSettle();

    expect(find.text('No members yet.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('album-invite-username')),
      'ada',
    );
    await tester.tap(find.byKey(const Key('album-invite-send')));
    await tester.pumpAndSettle();

    expect(find.text('ada'), findsOneWidget);
    expect(find.text('Invitation sent'), findsOneWidget);
    expect(log.singleWhere((entry) => entry.method == 'POST').jsonBody, {
      'username': 'ada',
    });
  });

  testWidgets('assigns a private category and blocks public ones', (
    tester,
  ) async {
    final fake = FakeApiHttp(
      profileBody: File(
        'test/fixtures/profile_success.json',
      ).readAsStringSync(),
      albumsBody:
          '{"albums":[{"id":7,"title":"Coast","image_count":0,"is_public":false}]}',
      categoriesBody:
          '{"categories":[{"id":1,"name":"Family","slug":"family","scope":"private","album_count":2},{"id":2,"name":"Travel","slug":"travel","scope":"public","album_count":0}]}',
      categoryAssignBody:
          '{"categories":[{"id":1,"name":"Family","slug":"family","scope":"private","album_count":3}]}',
    );
    final log = <ApiRequestLog>[];
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
        requestLog: log,
      ),
    );
    await auth.loginWithApiKey('k');
    final albums = AlbumService(clientProvider: () => auth.client!);
    final gallery = GalleryService(clientProvider: () => auth.client!);
    await pumpAlbums(tester, albums: albums, auth: auth, gallery: gallery);

    await tester.tap(find.text('Coast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Album actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('album-action-categories')));
    await tester.pumpAndSettle();

    expect(find.textContaining('starts empty'), findsOneWidget);
    final travel = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Travel'),
    );
    expect(travel.onChanged, isNull);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Family'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('album-category-save')));
    await tester.tap(find.byKey(const Key('album-category-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('album-category-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Categories saved'), findsOneWidget);
    expect(log.singleWhere((entry) => entry.method == 'PUT').jsonBody, {
      'private_category_ids': [1],
      'public_category_ids': <int>[],
    });
    expect(albums.assignedCategories(7)?.single.id, 1);
  });
}
