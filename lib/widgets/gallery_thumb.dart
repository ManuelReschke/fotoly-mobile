import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;

const String kGalleryCacheKey = 'pixelfoxGallery';
const String kGalleryThumbCacheKey = 'pixelfoxGalleryThumbs';

const int kGalleryThumbMaxEdge = 512;
const int kGalleryThumbJpegQuality = 80;
const int kGalleryThumbWorkers = 2;
const int kGalleryMaxConcurrentFetches = 3;

const Duration kGalleryCacheStalePeriod = Duration(days: 30);
const int kGalleryCacheMaxObjects = 500;

/// Bytes stored under an image URL. Thumbnails never download; originals do.
abstract class GalleryByteCache {
  Future<Uint8List?> read(String url);
  Future<void> write(String url, Uint8List bytes);
}

/// Longest edge becomes [kGalleryThumbMaxEdge]. Smaller images stay as they are.
({int width, int height}) galleryThumbSize(int width, int height) {
  if (width <= 0 || height <= 0) {
    return (width: 0, height: 0);
  }
  final longest = width > height ? width : height;
  if (longest <= kGalleryThumbMaxEdge) {
    return (width: width, height: height);
  }
  final scale = kGalleryThumbMaxEdge / longest;
  var scaledWidth = (width * scale).round();
  var scaledHeight = (height * scale).round();
  if (scaledWidth < 1) scaledWidth = 1;
  if (scaledHeight < 1) scaledHeight = 1;
  if (scaledWidth > kGalleryThumbMaxEdge) {
    scaledWidth = kGalleryThumbMaxEdge;
  }
  if (scaledHeight > kGalleryThumbMaxEdge) {
    scaledHeight = kGalleryThumbMaxEdge;
  }
  return (width: scaledWidth, height: scaledHeight);
}

Config galleryCacheConfig({FileSystem? fileSystem, CacheInfoRepository? repo}) {
  return _cacheConfig(
    kGalleryCacheKey,
    fileService: HttpFileService()
      ..concurrentFetches = kGalleryMaxConcurrentFetches,
    fileSystem: fileSystem,
    repo: repo,
  );
}

Config galleryThumbCacheConfig({
  FileSystem? fileSystem,
  CacheInfoRepository? repo,
}) {
  return _cacheConfig(
    kGalleryThumbCacheKey,
    fileSystem: fileSystem,
    repo: repo,
  );
}

Config _cacheConfig(
  String cacheKey, {
  FileService? fileService,
  FileSystem? fileSystem,
  CacheInfoRepository? repo,
}) {
  const stalePeriod = kGalleryCacheStalePeriod;
  const maxNrOfCacheObjects = kGalleryCacheMaxObjects;
  if (fileService != null && fileSystem != null && repo != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileService: fileService,
      fileSystem: fileSystem,
      repo: repo,
    );
  }
  if (fileService != null && fileSystem != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileService: fileService,
      fileSystem: fileSystem,
    );
  }
  if (fileService != null && repo != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileService: fileService,
      repo: repo,
    );
  }
  if (fileSystem != null && repo != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileSystem: fileSystem,
      repo: repo,
    );
  }
  if (fileService != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileService: fileService,
    );
  }
  if (fileSystem != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      fileSystem: fileSystem,
    );
  }
  if (repo != null) {
    return Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
      repo: repo,
    );
  }
  return Config(
    cacheKey,
    stalePeriod: stalePeriod,
    maxNrOfCacheObjects: maxNrOfCacheObjects,
  );
}

final Map<String, Future<Uint8List?>> _thumbJobs = {};
final _ThumbGate _thumbEncodeGate = _ThumbGate(kGalleryThumbWorkers);

/// Returns the cached JPEG, or builds one from [originals] and stores it.
///
/// The same [url] shares one in-flight job. Encoding is limited to
/// [kGalleryThumbWorkers] so a grid scroll does not decode every original
/// at once. Failures return null and leave the thumb cache unchanged.
Future<Uint8List?> materializeGalleryThumb({
  required String url,
  required GalleryByteCache originals,
  required GalleryByteCache thumbs,
  required Future<Uint8List> Function(Uint8List bytes) encode,
}) {
  final current = _thumbJobs[url];
  if (current != null) return current;
  final job = _materializeGalleryThumb(
    url: url,
    originals: originals,
    thumbs: thumbs,
    encode: encode,
  );
  _thumbJobs[url] = job;
  return job.whenComplete(() {
    if (identical(_thumbJobs[url], job)) {
      _thumbJobs.remove(url);
    }
  });
}

Future<Uint8List?> _materializeGalleryThumb({
  required String url,
  required GalleryByteCache originals,
  required GalleryByteCache thumbs,
  required Future<Uint8List> Function(Uint8List bytes) encode,
}) async {
  try {
    final cached = await thumbs.read(url);
    if (cached != null && cached.isNotEmpty) return cached;
    // Read the original only after a worker slot is free, so queued tiles
    // do not pin full-size files in memory.
    final jpeg = await _thumbEncodeGate.run(() async {
      final original = await originals.read(url);
      if (original == null || original.isEmpty) return Uint8List(0);
      return encode(original);
    });
    if (jpeg.isEmpty) return null;
    await thumbs.write(url, jpeg);
    return jpeg;
  } catch (_) {
    return null;
  }
}

/// Decodes [bytes] down to [kGalleryThumbMaxEdge] and JPEG-encodes that
/// bitmap on a background isolate.
Future<Uint8List> encodeGalleryThumb(Uint8List bytes) async {
  final frame = await _decodeThumbFrame(bytes);
  return compute(
    _jpegFromRgba,
    _RgbaPixels(frame.pixels, frame.width, frame.height),
  );
}

Future<({Uint8List pixels, int width, int height})> _decodeThumbFrame(
  Uint8List bytes,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  late final ui.ImageDescriptor descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
  } catch (_) {
    buffer.dispose();
    rethrow;
  }
  try {
    final size = galleryThumbSize(descriptor.width, descriptor.height);
    if (size.width == 0 || size.height == 0) {
      throw StateError('Image has no pixels');
    }
    final codec = await descriptor.instantiateCodec(
      targetWidth: size.width,
      targetHeight: size.height,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null) {
          throw StateError('Could not read image pixels');
        }
        return (
          pixels: Uint8List.fromList(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ),
          width: image.width,
          height: image.height,
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

class _RgbaPixels {
  const _RgbaPixels(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

Uint8List _jpegFromRgba(_RgbaPixels frame) {
  final image = img.Image.fromBytes(
    width: frame.width,
    height: frame.height,
    bytes: frame.pixels.buffer,
    bytesOffset: frame.pixels.offsetInBytes,
    numChannels: 4,
    rowStride: frame.width * 4,
  );
  return img.encodeJpg(image, quality: kGalleryThumbJpegQuality);
}

class _ThumbGate {
  _ThumbGate(this.limit);

  final int limit;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() action) async {
    // Recheck after waking. Another job can take the free slot before this
    // continuation runs.
    while (_active >= limit) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      return await action();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}
