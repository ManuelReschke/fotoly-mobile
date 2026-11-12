import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'gallery_image.dart';
import 'gallery_thumb.dart';

/// Square album thumbnail. [url] is the API `cover_stable_url`.
///
/// That URL is `/original/small`. When the derivative was never generated,
/// the same photo is loaded from `/original/original` and decoded at tile size.
class AlbumCoverImage extends StatefulWidget {
  const AlbumCoverImage({
    super.key,
    required this.url,
    this.originalBytes,
    this.thumbBytes,
    this.cacheManager,
  });

  final String url;
  final GalleryByteCache? originalBytes;
  final GalleryByteCache? thumbBytes;
  final BaseCacheManager? cacheManager;

  @override
  State<AlbumCoverImage> createState() => _AlbumCoverImageState();
}

class _AlbumCoverImageState extends State<AlbumCoverImage> {
  var _useOriginal = false;

  @override
  void didUpdateWidget(covariant AlbumCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _useOriginal = false;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = albumCoverOriginalUrl(widget.url);
    final url = _useOriginal && fallback != null ? fallback : widget.url;
    final canFallback = !_useOriginal && fallback != null;
    final cacheWidth = (56 * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: GalleryImage(
          key: ValueKey(url),
          url: url,
          fit: BoxFit.cover,
          memCacheWidth: cacheWidth,
          originalBytes: widget.originalBytes,
          thumbBytes: widget.thumbBytes,
          cacheManager: widget.cacheManager,
          onUnavailable: canFallback
              ? () {
                  if (!mounted) return;
                  setState(() => _useOriginal = true);
                }
              : null,
        ),
      ),
    );
  }
}

final RegExp _smallOriginalCover = RegExp(r'/original/small\.([A-Za-z0-9]+)$');

/// Original stable URL for an API cover that points at `/original/small`.
///
/// The album API always returns that small derivative. `original_only`
/// uploads never generate it, so the URL 404s. The same file at
/// `/original/original` is the one the gallery already displays.
///
/// Returns null when [coverUrl] is not that small original variant.
String? albumCoverOriginalUrl(String coverUrl) {
  final trimmed = coverUrl.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final match = _smallOriginalCover.firstMatch(uri.path);
  if (match == null) return null;
  final originalPath = uri.path.replaceRange(
    match.start,
    match.end,
    '/original/original.${match.group(1)}',
  );
  return uri.replace(path: originalPath).toString();
}
