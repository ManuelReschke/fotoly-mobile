import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/l10n/locale_controller.dart';
import 'package:fotoly_mobile/screens/gallery_screen.dart';
import 'package:fotoly_mobile/screens/gallery_viewer.dart';
import 'package:fotoly_mobile/services/gallery_service.dart';
import 'package:fotoly_mobile/services/pixelfox_api_client.dart';
import 'package:fotoly_mobile/services/storage.dart';
import 'package:fotoly_mobile/widgets/gallery_zoom.dart';
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

Transform? _zoomedTransform(WidgetTester tester) {
  Transform? zoomed;
  var maxScale = 0.0;
  for (final transform in tester.widgetList<Transform>(
    find.descendant(
      of: find.byType(GalleryViewer),
      matching: find.byType(Transform),
    ),
  )) {
    final scale = transform.transform.getMaxScaleOnAxis();
    if (scale > maxScale) {
      maxScale = scale;
      zoomed = transform;
    }
  }
  return zoomed;
}

double viewerScale(WidgetTester tester) {
  return _zoomedTransform(tester)?.transform.getMaxScaleOnAxis() ?? 0;
}

Offset viewerTranslation(WidgetTester tester) {
  final translation = _zoomedTransform(tester)?.transform.getTranslation();
  if (translation == null) return Offset.zero;
  return Offset(translation.x, translation.y);
}

Finder viewerText(String url) {
  return find.descendant(
    of: find.byType(GalleryViewer),
    matching: find.text(url),
  );
}

void main() {
  test('zoom offset keeps the pinch point and covers the viewport', () {
    const viewport = Size(400, 800);
    const focal = Offset(200, 400);
    final centered = galleryZoomOffset(
      focalPoint: focal,
      childFocal: focal,
      scale: 2,
      viewport: viewport,
    );
    expect(centered, const Offset(-200, -400));

    final pastLeftEdge = galleryZoomOffset(
      focalPoint: const Offset(-100, 400),
      childFocal: focal,
      scale: 2,
      viewport: viewport,
    );
    expect(pastLeftEdge.dx, -400);
    expect(pastLeftEdge.dy, -400);

    expect(
      galleryZoomOffset(
        focalPoint: focal,
        childFocal: focal,
        scale: 1,
        viewport: viewport,
      ),
      Offset.zero,
    );
  });

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

  testWidgets('sort menu reloads oldest first', (tester) async {
    final fake = FakeApiHttp(
      imagesStatus: 200,
      imagesBody:
          '{"items":['
          '{"image_uuid":"a","stable_url":"https://example/a.jpg"}'
          '],"has_more":false}',
    );
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(apiKey: 'k', httpClient: fake),
    );
    await pumpGallery(tester, gallery: gallery);
    expect(find.text('https://example/a.jpg'), findsOneWidget);

    await tester.tap(find.byTooltip('Photo order'));
    await tester.pumpAndSettle();
    expect(find.text('Newest first'), findsOneWidget);
    expect(find.text('Oldest first'), findsOneWidget);
    expect(
      tester
          .widget<CheckedPopupMenuItem<GallerySort>>(
            find.widgetWithText(
              CheckedPopupMenuItem<GallerySort>,
              'Newest first',
            ),
          )
          .checked,
      isTrue,
    );

    fake.imagesBody =
        '{"items":[{"image_uuid":"old","stable_url":"https://example/old.jpg"}],"has_more":false}';
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<GallerySort>, 'Oldest first'),
    );
    await tester.pumpAndSettle();

    final imageUrls = fake.sent
        .map((request) => request.url)
        .where((url) => url.path.endsWith('/images'))
        .map((url) => url.toString())
        .toList();
    expect(imageUrls.first, isNot(contains('sort=')));
    expect(imageUrls.last, contains('sort=asc'));
    expect(find.text('https://example/a.jpg'), findsNothing);
    expect(find.text('https://example/old.jpg'), findsOneWidget);
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

  testWidgets('viewer swipe moves to the next photo', (tester) async {
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
    await tester.tap(find.text('https://example/a.jpg'));
    await tester.pumpAndSettle();
    expect(viewerText('https://example/a.jpg'), findsOneWidget);

    await tester.fling(
      find.byType(GalleryZoom).hitTestable(),
      const Offset(-500, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(viewerText('https://example/b.jpg').hitTestable(), findsOneWidget);
    expect(viewerText('https://example/a.jpg').hitTestable(), findsNothing);
  });

  testWidgets('viewer pinch zooms in and back out', (tester) async {
    final gallery = GalleryService(
      clientProvider: () => PixelfoxApiClient(
        apiKey: 'k',
        httpClient: FakeApiHttp(
          imagesStatus: 200,
          imagesBody:
              '{"items":['
              '{"image_uuid":"a","stable_url":"https://example/a.jpg"}'
              '],"has_more":false}',
        ),
      ),
    );
    await pumpGallery(tester, gallery: gallery);
    await tester.tap(find.text('https://example/a.jpg'));
    await tester.pumpAndSettle();
    expect(viewerScale(tester), closeTo(1, 0.01));

    final center = tester.getCenter(find.byType(GalleryZoom));
    final finger1 = await tester.startGesture(center.translate(-20, 0));
    final finger2 = await tester.startGesture(center.translate(20, 0));
    addTearDown(finger1.removePointer);
    addTearDown(finger2.removePointer);
    await tester.pump();
    await finger1.moveTo(center.translate(-120, 0));
    await finger2.moveTo(center.translate(120, 0));
    await tester.pump();

    final zoomed = viewerScale(tester);
    expect(zoomed, greaterThan(2));

    await finger1.moveTo(center.translate(-30, 0));
    await finger2.moveTo(center.translate(30, 0));
    await tester.pump();
    final pulledBack = viewerScale(tester);
    expect(pulledBack, lessThan(zoomed));
    expect(pulledBack, greaterThan(1));

    await finger1.up();
    await finger2.up();
    await tester.pump();
  });

  testWidgets('viewer does not page while zoomed', (tester) async {
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
    await tester.tap(find.text('https://example/a.jpg'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(GalleryZoom));
    final finger1 = await tester.startGesture(center.translate(-20, 0));
    final finger2 = await tester.startGesture(center.translate(20, 0));
    addTearDown(finger1.removePointer);
    addTearDown(finger2.removePointer);
    await finger1.moveTo(center.translate(-120, 0));
    await finger2.moveTo(center.translate(120, 0));
    await tester.pump();
    expect(viewerScale(tester), greaterThan(2));
    await finger1.up();
    await finger2.up();
    await tester.pumpAndSettle();

    final pan = await tester.startGesture(center);
    addTearDown(pan.removePointer);
    await pan.moveBy(const Offset(30, 0));
    await tester.pump();
    final beforePan = viewerTranslation(tester);
    await pan.moveBy(const Offset(80, -40));
    await tester.pump();
    final afterPan = viewerTranslation(tester);
    expect(afterPan.dx, greaterThan(beforePan.dx));
    expect(afterPan.dy, lessThan(beforePan.dy));
    await pan.up();
    await tester.pump();

    await tester.fling(
      find.byType(GalleryZoom).hitTestable(),
      const Offset(-500, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(viewerText('https://example/a.jpg').hitTestable(), findsOneWidget);
    expect(viewerText('https://example/b.jpg').hitTestable(), findsNothing);
    expect(viewerScale(tester), greaterThan(2));
  });
}
