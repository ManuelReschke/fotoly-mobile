import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixelfox_mobile/l10n/locale_controller.dart';
import 'package:pixelfox_mobile/screens/gallery_screen.dart';
import 'package:pixelfox_mobile/screens/gallery_viewer.dart';
import 'package:pixelfox_mobile/services/gallery_service.dart';
import 'package:pixelfox_mobile/services/pixelfox_api_client.dart';
import 'package:pixelfox_mobile/services/storage.dart';
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
      child: MaterialApp(home: GalleryScreen(imageBuilder: stubImage)),
    ),
  );
  await tester.pump(); // ensureLoaded starts
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
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
        httpClient: FakeApiHttp(imagesStatus: 500, imagesBody: '{"error":"x"}'),
      ),
    );
    await pumpGallery(tester, gallery: gallery);
    expect(find.textContaining('Could not load images'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('first-load 401 shows invalid-key message', (tester) async {
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          imagesStatus: 401,
          imagesBody: '{"error":"unauthorized"}',
        ),
      ),
    );
    await pumpGallery(tester, gallery: gallery);
    expect(find.textContaining('Invalid API key'), findsOneWidget);
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

  testWidgets('viewer opens with stub image and tap pops', (tester) async {
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
    await tester.tap(find.text('https://example/b.jpg'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GalleryViewer),
        matching: find.text('https://example/b.jpg'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(GalleryViewer),
        matching: find.text('https://example/b.jpg'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsNothing);
  });

  testWidgets('viewer pops when refresh replaces items with empty list', (
    tester,
  ) async {
    final fake = FakeApiHttp(
      imagesStatus: 200,
      imagesBody:
          '{"items":['
          '{"image_uuid":"a","stable_url":"https://example/a.jpg"},'
          '{"image_uuid":"b","stable_url":"https://example/b.jpg"}'
          '],"has_more":false}',
    );
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await pumpGallery(tester, gallery: gallery);
    await tester.tap(find.text('https://example/b.jpg'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsOneWidget);

    fake.imagesBody = '{"items":[],"has_more":false}';
    await gallery.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsNothing);
  });

  testWidgets('viewer survives list shrink under open page', (tester) async {
    final fake = FakeApiHttp(
      imagesStatus: 200,
      imagesBody:
          '{"items":['
          '{"image_uuid":"a","stable_url":"https://example/a.jpg"},'
          '{"image_uuid":"b","stable_url":"https://example/b.jpg"},'
          '{"image_uuid":"c","stable_url":"https://example/c.jpg"}'
          '],"has_more":false}',
    );
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await pumpGallery(tester, gallery: gallery);
    await tester.tap(find.text('https://example/c.jpg'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryViewer), findsOneWidget);

    fake.imagesBody =
        '{"items":[{"image_uuid":"a","stable_url":"https://example/a.jpg"}],'
        '"has_more":false}';
    await gallery.refresh();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryViewer), findsOneWidget);
  });
}
