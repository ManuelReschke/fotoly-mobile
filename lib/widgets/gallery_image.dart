import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'gallery_thumb.dart';

export 'gallery_thumb.dart' show kGalleryCacheKey;

typedef GalleryImageBuilder =
    Widget Function({
      required String url,
      required BoxFit fit,
      int? memCacheWidth,
      int? memCacheHeight,
    });

CacheManager? _galleryCache;
CacheManager? _thumbCache;

CacheManager galleryCacheManager() {
  return _galleryCache ??= CacheManager(galleryCacheConfig());
}

CacheManager galleryThumbCacheManager() {
  return _thumbCache ??= CacheManager(galleryThumbCacheConfig());
}

/// Grid and album tiles pass a cache size and use the local preview.
/// The fullscreen viewer sets [preview] false and decodes the original
/// at its own cache size.
bool galleryImageUsesThumb({
  int? memCacheWidth,
  int? memCacheHeight,
  bool preview = true,
}) {
  // Web ImageDescriptor has no dimensions, so the thumb encoder cannot run.
  if (kIsWeb || !preview) return false;
  return memCacheWidth != null || memCacheHeight != null;
}

class GalleryImage extends StatelessWidget {
  const GalleryImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorLabel,
    this.cacheManager,
    this.originalBytes,
    this.thumbBytes,
    this.preview = true,
  });

  final String url;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? errorLabel;
  final BaseCacheManager? cacheManager;
  final GalleryByteCache? originalBytes;
  final GalleryByteCache? thumbBytes;

  /// When false, [memCacheWidth] only caps the decoded original.
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final cache = cacheManager ?? galleryCacheManager();
    if (galleryImageUsesThumb(
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      preview: preview,
    )) {
      return _GalleryThumbImage(
        url: url,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        errorLabel: errorLabel,
        originals:
            originalBytes ?? _CacheManagerByteCache(cache, download: true),
        thumbs:
            thumbBytes ?? _CacheManagerByteCache(galleryThumbCacheManager()),
        networkCache: cache,
      );
    }
    return _networkGalleryImage(
      url: url,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      errorLabel: errorLabel,
      cacheManager: cache,
    );
  }
}

/// Reads a file that is still on disk, even after [FileInfo.validTill].
///
/// [CacheManager.getSingleFile] downloads again once that deadline passes.
/// The on-screen image already revalidates, so a thumb must not.
Future<Uint8List?> readGalleryCacheBytes({
  required BaseCacheManager cache,
  required String url,
  bool download = false,
}) async {
  try {
    final file = (await cache.getFileFromCache(url))?.file;
    if (file != null && await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
    if (!download) return null;
    final downloaded = await (await cache.getSingleFile(url)).readAsBytes();
    if (downloaded.isEmpty) return null;
    return downloaded;
  } catch (_) {
    return null;
  }
}

class _CacheManagerByteCache implements GalleryByteCache {
  _CacheManagerByteCache(this._cache, {this.download = false});

  final BaseCacheManager _cache;
  final bool download;

  @override
  Future<Uint8List?> read(String url) {
    return readGalleryCacheBytes(cache: _cache, url: url, download: download);
  }

  @override
  Future<void> write(String url, Uint8List bytes) async {
    await _cache.putFile(url, bytes, fileExtension: 'jpg');
  }
}

class _GalleryThumbImage extends StatefulWidget {
  const _GalleryThumbImage({
    required this.url,
    required this.fit,
    required this.memCacheWidth,
    required this.memCacheHeight,
    required this.errorLabel,
    required this.originals,
    required this.thumbs,
    required this.networkCache,
  });

  final String url;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? errorLabel;
  final GalleryByteCache originals;
  final GalleryByteCache thumbs;
  final BaseCacheManager networkCache;

  @override
  State<_GalleryThumbImage> createState() => _GalleryThumbImageState();
}

class _GalleryThumbImageState extends State<_GalleryThumbImage> {
  Uint8List? _bytes;
  var _showOriginal = false;
  var _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _GalleryThumbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _bytes = null;
    _showOriginal = false;
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final url = widget.url;
    Uint8List? cached;
    try {
      cached = await widget.thumbs.read(url);
    } catch (_) {
      cached = null;
    }
    if (!mounted || request != _request) return;
    if (cached != null && cached.isNotEmpty) {
      setState(() => _bytes = cached);
      return;
    }
    setState(() => _showOriginal = true);
    final made = await materializeGalleryThumb(
      url: url,
      originals: widget.originals,
      thumbs: widget.thumbs,
      encode: encodeGalleryThumb,
    );
    if (!mounted || request != _request) return;
    if (made != null && made.isNotEmpty) {
      setState(() => _bytes = made);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: widget.memCacheWidth,
        cacheHeight: widget.memCacheHeight,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _galleryImageError(context, widget.errorLabel),
      );
    }
    if (_showOriginal) {
      return _networkGalleryImage(
        url: widget.url,
        fit: widget.fit,
        memCacheWidth: widget.memCacheWidth,
        memCacheHeight: widget.memCacheHeight,
        errorLabel: widget.errorLabel,
        cacheManager: widget.networkCache,
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

Widget _networkGalleryImage({
  required String url,
  required BoxFit fit,
  required int? memCacheWidth,
  required int? memCacheHeight,
  required String? errorLabel,
  required BaseCacheManager cacheManager,
}) {
  return CachedNetworkImage(
    cacheManager: cacheManager,
    imageUrl: url,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    memCacheWidth: memCacheWidth,
    memCacheHeight: memCacheHeight,
    placeholder: (context, url) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    errorWidget: (context, url, error) =>
        _galleryImageError(context, errorLabel),
  );
}

Widget _galleryImageError(BuildContext context, String? errorLabel) {
  final scheme = Theme.of(context).colorScheme;
  return ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
        if (errorLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    ),
  );
}
