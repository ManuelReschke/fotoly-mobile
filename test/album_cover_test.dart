import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/widgets/album_cover.dart';
import 'package:fotoly_mobile/widgets/gallery_thumb.dart';
import 'package:image/image.dart' as img;

void main() {
  test('small cover url falls back to the original stable file', () {
    expect(
      albumCoverOriginalUrl('https://fotoly.eu/f/abc/original/small.jpg'),
      'https://fotoly.eu/f/abc/original/original.jpg',
    );
    expect(
      albumCoverOriginalUrl('https://fotoly.eu/f/abc/original/small.png?v=1'),
      'https://fotoly.eu/f/abc/original/original.png?v=1',
    );
    expect(
      albumCoverOriginalUrl('/f/abc/original/small.jpeg'),
      '/f/abc/original/original.jpeg',
    );
  });

  test('cover fallback leaves urls that are not the small original', () {
    expect(
      albumCoverOriginalUrl('https://fotoly.eu/f/abc/original/original.jpg'),
      isNull,
    );
    expect(
      albumCoverOriginalUrl('https://fotoly.eu/f/abc/webp/small.webp'),
      isNull,
    );
    expect(albumCoverOriginalUrl('https://example/cover.jpg'), isNull);
    expect(albumCoverOriginalUrl(''), isNull);
  });

  testWidgets(
    'album cover shows the original when the small preview is missing',
    (tester) async {
      const small = 'https://fotoly.eu/f/abc/original/small.jpg';
      const original = 'https://fotoly.eu/f/abc/original/original.jpg';
      final jpeg = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 2, height: 2)),
      );
      final thumbs = _MemoryByteCache()..files[original] = jpeg;
      final originals = _MemoryByteCache();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumCoverImage(
              url: small,
              originalBytes: originals,
              thumbBytes: thumbs,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      final memory = provider is ResizeImage
          ? provider.imageProvider
          : provider;
      expect(memory, isA<MemoryImage>());
      expect((memory as MemoryImage).bytes, jpeg);
      expect(thumbs.urls, contains(small));
      expect(originals.urls, contains(small));
      expect(thumbs.urls, contains(original));
    },
  );
}

class _MemoryByteCache implements GalleryByteCache {
  final Map<String, Uint8List> files = {};
  final List<String> urls = [];

  @override
  Future<Uint8List?> read(String url) async {
    urls.add(url);
    final bytes = files[url];
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> write(String url, Uint8List bytes) async {
    files[url] = Uint8List.fromList(bytes);
  }
}
