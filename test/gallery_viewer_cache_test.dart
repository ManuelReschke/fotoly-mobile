import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/gallery_viewer.dart';
import 'package:fotoly_mobile/services/gallery_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:provider/provider.dart';

import 'fake_api_http.dart';

void main() {
  test('viewer decode edge is screen width times pixel ratio times 2', () {
    expect(
      galleryViewerCacheEdge(viewportWidth: 400, devicePixelRatio: 3),
      2400,
    );
    expect(
      galleryViewerCacheEdge(viewportWidth: 100, devicePixelRatio: 1),
      200,
    );
    expect(galleryViewerCacheEdge(viewportWidth: 0, devicePixelRatio: 3), 1);
  });

  test('viewer prefetches the next two photos', () {
    expect(galleryViewerPrefetchIndexes(index: 0, length: 4), [1, 2]);
    expect(galleryViewerPrefetchIndexes(index: 2, length: 4), [3]);
    expect(galleryViewerPrefetchIndexes(index: 3, length: 4), isEmpty);
    expect(galleryViewerPrefetchIndexes(index: 0, length: 0), isEmpty);
  });

  test('viewer provider keeps the original url and the decode width', () {
    final provider = galleryViewerImageProvider(
      url: 'https://example/a.jpg',
      cacheEdge: 2400,
    );
    final resized = provider as ResizeImage;
    expect(resized.width, 2400);
    expect(resized.height, isNull);
    expect(
      (resized.imageProvider as CachedNetworkImageProvider).url,
      'https://example/a.jpg',
    );
  });

  testWidgets('open viewer caps the photo and prefetches the next two', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recorded = <(String, int)>[];
    final widths = <String, int?>{};
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          imagesStatus: 200,
          imagesBody:
              '{"items":['
              '{"image_uuid":"a","stable_url":"https://example/a.jpg"},'
              '{"image_uuid":"b","stable_url":"https://example/b.jpg"},'
              '{"image_uuid":"c","stable_url":"https://example/c.jpg"}'
              '],"has_more":false}',
        ),
      ),
    );
    await gallery.ensureLoaded();
    final locale = LocaleController(prefs: MemoryPrefsStore());
    await locale.setLocale(AppLocale.en);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LocaleController>.value(value: locale),
          ChangeNotifierProvider<GalleryService>.value(value: gallery),
        ],
        child: MaterialApp(
          home: GalleryViewer(
            initialIndex: 0,
            onPrecache: (url, cacheEdge) => recorded.add((url, cacheEdge)),
            imageBuilder:
                ({
                  required String url,
                  required BoxFit fit,
                  int? memCacheWidth,
                  int? memCacheHeight,
                }) {
                  widths[url] = memCacheWidth;
                  return Text(url);
                },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(widths['https://example/a.jpg'], 2400);
    expect(recorded, [
      ('https://example/b.jpg', 2400),
      ('https://example/c.jpg', 2400),
    ]);
  });
}
