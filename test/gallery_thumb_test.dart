import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' hide FileSystem;
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/widgets/gallery_image.dart';
import 'package:fotoly_mobile/widgets/gallery_thumb.dart';
import 'package:image/image.dart' as img;

Config _quietCacheConfig(
  Config Function({FileSystem? fileSystem, CacheInfoRepository? repo}) build,
) {
  return build(fileSystem: _IdleFileSystem(), repo: NonStoringObjectProvider());
}

class _IdleFileSystem implements FileSystem {
  @override
  Future<File> createFile(String name) {
    throw UnsupportedError(name);
  }
}

class MemoryByteCache implements GalleryByteCache {
  final Map<String, Uint8List> files = {};
  int reads = 0;

  @override
  Future<Uint8List?> read(String url) async {
    reads++;
    final bytes = files[url];
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> write(String url, Uint8List bytes) async {
    files[url] = Uint8List.fromList(bytes);
  }
}

void main() {
  test('thumb size caps the longest edge at 512', () {
    expect(galleryThumbSize(4000, 3000), (width: 512, height: 384));
    expect(galleryThumbSize(3000, 4000), (width: 384, height: 512));
    expect(galleryThumbSize(1000, 400), (width: 512, height: 205));
    expect(galleryThumbSize(400, 300), (width: 400, height: 300));
    expect(galleryThumbSize(0, 300), (width: 0, height: 0));
  });

  test('gallery cache fetches at most 3 files at once', () {
    final config = _quietCacheConfig(galleryCacheConfig);
    expect(config.fileService.concurrentFetches, 3);
    expect(config.cacheKey, kGalleryCacheKey);
    expect(config.maxNrOfCacheObjects, 500);
    expect(config.stalePeriod, const Duration(days: 30));
  });

  test('an injected filesystem is kept on its own', () {
    final fileSystem = _IdleFileSystem();
    final config = galleryCacheConfig(fileSystem: fileSystem);
    expect(config.fileSystem, same(fileSystem));
    expect(config.fileService.concurrentFetches, 3);
  });

  test('thumb cache keeps 500 previews for 30 days', () {
    final config = _quietCacheConfig(galleryThumbCacheConfig);
    expect(config.cacheKey, 'pixelfoxGalleryThumbs');
    expect(config.maxNrOfCacheObjects, 500);
    expect(config.stalePeriod, const Duration(days: 30));
  });

  test('a stored thumb is reused without reading the original', () async {
    var encodes = 0;
    final thumbs = MemoryByteCache()
      ..files['u'] = Uint8List.fromList(const [7, 7]);
    final originals = MemoryByteCache()
      ..files['u'] = Uint8List.fromList(const [1]);

    final result = await materializeGalleryThumb(
      url: 'u',
      originals: originals,
      thumbs: thumbs,
      encode: (_) async {
        encodes++;
        return Uint8List.fromList(const [9]);
      },
    );

    expect(result, Uint8List.fromList(const [7, 7]));
    expect(encodes, 0);
    expect(originals.reads, 0);
  });

  test('missing original does not write a thumb', () async {
    var encodes = 0;
    final thumbs = MemoryByteCache();
    final result = await materializeGalleryThumb(
      url: 'missing',
      originals: MemoryByteCache(),
      thumbs: thumbs,
      encode: (_) async {
        encodes++;
        return Uint8List.fromList(const [9]);
      },
    );

    expect(result, isNull);
    expect(encodes, 0);
    expect(thumbs.files, isEmpty);
  });

  test('a failed encode leaves the thumb cache empty', () async {
    final thumbs = MemoryByteCache();
    final result = await materializeGalleryThumb(
      url: 'u',
      originals: MemoryByteCache()..files['u'] = Uint8List.fromList(const [1]),
      thumbs: thumbs,
      encode: (_) async => throw StateError('bad image'),
    );

    expect(result, isNull);
    expect(thumbs.files, isEmpty);
  });

  test('the same original is encoded once', () async {
    var encodes = 0;
    final originals = MemoryByteCache()
      ..files['u'] = Uint8List.fromList(const [1, 2, 3]);
    final thumbs = MemoryByteCache();

    Future<Uint8List> encode(Uint8List bytes) async {
      encodes++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return Uint8List.fromList(bytes);
    }

    final results = await Future.wait([
      materializeGalleryThumb(
        url: 'u',
        originals: originals,
        thumbs: thumbs,
        encode: encode,
      ),
      materializeGalleryThumb(
        url: 'u',
        originals: originals,
        thumbs: thumbs,
        encode: encode,
      ),
    ]);

    expect(encodes, 1);
    expect(results[0], Uint8List.fromList(const [1, 2, 3]));
    expect(results[1], results[0]);
  });

  test('encodes at most two thumbs at once', () async {
    var active = 0;
    var maxActive = 0;
    final originals = MemoryByteCache();
    final thumbs = MemoryByteCache();
    for (var i = 0; i < 4; i++) {
      originals.files['u$i'] = Uint8List.fromList([i + 1]);
    }

    Future<Uint8List> encode(Uint8List bytes) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      active--;
      return Uint8List.fromList(bytes);
    }

    await Future.wait([
      for (var i = 0; i < 4; i++)
        materializeGalleryThumb(
          url: 'u$i',
          originals: originals,
          thumbs: thumbs,
          encode: encode,
        ),
    ]);

    expect(maxActive, 2);
    expect(thumbs.files.length, 4);
  });

  test(
    'a queued thumb does not read the original until a worker is free',
    () async {
      final release = Completer<void>();
      var active = 0;
      final originals = MemoryByteCache();
      final thumbs = MemoryByteCache();
      for (var i = 0; i < 4; i++) {
        originals.files['u$i'] = Uint8List.fromList([i + 1]);
      }

      Future<Uint8List> encode(Uint8List bytes) async {
        active++;
        await release.future;
        active--;
        return bytes;
      }

      final pending = <Future<Uint8List?>>[
        for (var i = 0; i < 4; i++)
          materializeGalleryThumb(
            url: 'u$i',
            originals: originals,
            thumbs: thumbs,
            encode: encode,
          ),
      ];

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(active, 2);
      expect(originals.reads, 2);

      release.complete();
      await Future.wait(pending);
      expect(originals.reads, 4);
      expect(thumbs.files.length, 4);
    },
  );

  test('encodeGalleryThumb writes a jpeg whose longest edge is 512', () async {
    final source = img.Image(width: 1000, height: 400);
    img.fill(source, color: img.ColorRgb8(200, 10, 10));
    final jpeg = await encodeGalleryThumb(img.encodePng(source));
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
    final decoded = img.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, 205);
  });

  test('encodeGalleryThumb composites straight alpha onto white', () async {
    final source = img.Image(width: 8, height: 8, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(200, 10, 10, 128));
    final jpeg = await encodeGalleryThumb(img.encodePng(source));
    final decoded = img.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    final pixel = decoded!.getPixel(4, 4);
    // 200 * 128/255 + 255 * (1 - 128/255) is about 227. Premultiplied
    // input would land near 177.
    expect(pixel.r, inInclusiveRange(205, 245));
  });

  test('only a sized tile uses the thumb cache', () {
    expect(galleryImageUsesThumb(memCacheWidth: 120), isTrue);
    expect(galleryImageUsesThumb(memCacheHeight: 80), isTrue);
    expect(galleryImageUsesThumb(), isFalse);
    expect(galleryImageUsesThumb(memCacheWidth: 2400, preview: false), isFalse);
  });

  testWidgets('a sized tile paints the stored thumb', (tester) async {
    const url = 'https://fotoly.eu/f/abc/original/original.jpg';
    final thumbs = MemoryByteCache()..files[url] = _onePixelJpeg;
    final originals = MemoryByteCache()
      ..files[url] = Uint8List.fromList(const [1, 2, 3, 4]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GalleryImage(
            url: url,
            memCacheWidth: 48,
            originalBytes: originals,
            thumbBytes: thumbs,
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image;
    expect(resized, isA<ResizeImage>());
    expect((resized as ResizeImage).width, 48);
    expect((resized.imageProvider as MemoryImage).bytes, _onePixelJpeg);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(originals.reads, 0);
  });

  test('a stale cached original is reused without a new download', () async {
    final stale = Uint8List.fromList(const [9, 9, 9]);
    final cache = _ScriptedCache(cached: stale);
    final bytes = await readGalleryCacheBytes(
      cache: cache,
      url: 'https://example/a.jpg',
      download: true,
    );
    expect(bytes, stale);
    expect(cache.downloads, 0);
  });

  test('a missing original is downloaded', () async {
    final downloaded = Uint8List.fromList(const [1, 2]);
    final cache = _ScriptedCache(downloaded: downloaded);
    final bytes = await readGalleryCacheBytes(
      cache: cache,
      url: 'https://example/a.jpg',
      download: true,
    );
    expect(bytes, downloaded);
    expect(cache.downloads, 1);
  });
}

class _ScriptedCache extends BaseCacheManager {
  _ScriptedCache({this.cached, this.downloaded});

  final Uint8List? cached;
  final Uint8List? downloaded;
  var downloads = 0;

  Future<File> _file(Uint8List bytes) async {
    final file = MemoryFileSystem().file('/bytes.bin');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    final bytes = cached;
    if (bytes == null) return null;
    return FileInfo(
      await _file(bytes),
      FileSource.Cache,
      DateTime.fromMillisecondsSinceEpoch(0),
      key,
    );
  }

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    downloads++;
    final bytes = downloaded;
    if (bytes == null) {
      throw StateError('no download');
    }
    return _file(bytes);
  }

  @override
  Stream<FileInfo> getFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) async => null;

  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeFile(String key) {
    throw UnimplementedError();
  }

  @override
  Future<void> emptyCache() {
    throw UnimplementedError();
  }

  @override
  Future<void> dispose() async {}
}

/// 1×1 JPEG. Enough for [Image.memory] to resolve in a widget test.
final Uint8List _onePixelJpeg = Uint8List.fromList(const [
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, //
  0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09, //
  0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, //
  0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, //
  0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, //
  0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32, //
  0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, //
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x09, 0xFF, 0xC4, 0x00, 0x14, 0x10, 0x01, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, //
  0x7F, 0xFF, 0xD9,
]);
