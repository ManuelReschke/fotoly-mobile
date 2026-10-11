import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/album_detail_screen.dart';
import 'package:fotoly_mobile/screens/albums_screen.dart';
import 'package:fotoly_mobile/services/album_service.dart';
import 'package:fotoly_mobile/services/auth_service.dart';
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
  return ColoredBox(color: Colors.grey, child: Text(url, maxLines: 1));
}

Future<void> pumpAlbums(
  WidgetTester tester, {
  required AlbumService albums,
  GalleryService? gallery,
  AuthService? auth,
}) async {
  final locale = LocaleController(prefs: MemoryPrefsStore());
  await locale.setLocale(AppLocale.en);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<AlbumService>.value(value: albums),
        if (gallery != null)
          ChangeNotifierProvider<GalleryService>.value(value: gallery),
        if (auth != null)
          ChangeNotifierProvider<AuthService>.value(value: auth),
      ],
      child: MaterialApp(home: AlbumsScreen(imageBuilder: stubImage)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('empty state offers a new album', (tester) async {
    final albums = AlbumService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(albumsBody: '{"albums":[]}'),
      ),
    );
    await pumpAlbums(tester, albums: albums);
    expect(find.text('No albums yet'), findsOneWidget);
    expect(find.text('New album'), findsWidgets);
  });

  testWidgets('lists an album and opens its photos', (tester) async {
    final fake = FakeApiHttp(
      profileBody: File(
        'test/fixtures/profile_success.json',
      ).readAsStringSync(),
      albumsBody:
          '{"albums":[{"id":7,"title":"Coast","image_count":2,"is_public":true,"view_url":"/a/coast"}]}',
      imagesBody:
          '{"items":[{"image_uuid":"pic","stable_url":"https://example/pic.jpg"}],"has_more":false}',
    );
    final auth = AuthService(
      secureStore: MemorySecureStore(),
      clientFactory: ({apiKey, accessToken}) => PixelfoxApiClient(
        apiKey: apiKey,
        accessToken: accessToken,
        httpClient: fake,
      ),
    );
    await auth.loginWithApiKey('k');
    final albums = AlbumService(clientProvider: () => auth.client!);
    final gallery = GalleryService(clientProvider: () => auth.client!);
    await pumpAlbums(tester, albums: albums, gallery: gallery, auth: auth);

    expect(find.text('Coast'), findsOneWidget);
    expect(find.textContaining('Public'), findsOneWidget);

    await tester.tap(find.text('Coast'));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumDetailScreen), findsOneWidget);
    expect(find.text('https://example/pic.jpg'), findsOneWidget);
  });

  testWidgets('create sheet adds the album to the list', (tester) async {
    final fake = FakeApiHttp(
      albumsBody: '{"albums":[]}',
      albumWriteStatus: 201,
      albumWriteBody:
          '{"id":3,"title":"Holiday","image_count":0,"is_public":false}',
    );
    final albums = AlbumService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await pumpAlbums(tester, albums: albums);

    await tester.tap(find.byKey(const Key('albums-create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Holiday');
    await tester.ensureVisible(find.byKey(const Key('album-save')));
    await tester.tap(find.byKey(const Key('album-save')));
    await tester.pumpAndSettle();

    expect(find.text('Holiday'), findsOneWidget);
    expect(find.text('Album created'), findsOneWidget);
  });

  testWidgets('new album button stays above the system navigation bar', (
    tester,
  ) async {
    const navBar = 48.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
    tester.view.padding = const FakeViewPadding(bottom: navBar);
    addTearDown(tester.view.reset);

    final albums = AlbumService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(albumsBody: '{"albums":[]}'),
      ),
    );
    await pumpAlbums(tester, albums: albums);
    await tester.tap(find.byKey(const Key('albums-create')));
    await tester.pumpAndSettle();

    final button = tester.getRect(find.byKey(const Key('album-save')));
    expect(1600 - button.bottom, greaterThanOrEqualTo(navBar));
  });
}
