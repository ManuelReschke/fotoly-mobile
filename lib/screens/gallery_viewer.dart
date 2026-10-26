import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_scope.dart';
import '../models/pixelfox_image.dart';
import '../services/gallery_service.dart';
import '../widgets/gallery_image.dart';
import '../widgets/gallery_zoom.dart';

/// Decode width for a fitted photo that stays sharp through a 2× pinch.
///
/// Only the width is capped. The height follows the photo, so the bitmap
/// keeps its aspect ratio.
int galleryViewerCacheEdge({
  required double viewportWidth,
  required double devicePixelRatio,
}) {
  if (viewportWidth <= 0 || devicePixelRatio <= 0) return 1;
  final edge = (viewportWidth * devicePixelRatio * 2).round();
  return edge < 1 ? 1 : edge;
}

/// Indexes of the next two photos after [index].
List<int> galleryViewerPrefetchIndexes({
  required int index,
  required int length,
}) {
  if (length <= 0 || index < 0) return const [];
  final indexes = <int>[];
  if (index + 1 < length) indexes.add(index + 1);
  if (index + 2 < length) indexes.add(index + 2);
  return indexes;
}

/// Original file decoded at [cacheEdge]. Matches the fullscreen [GalleryImage].
ImageProvider<Object> galleryViewerImageProvider({
  required String url,
  required int cacheEdge,
  BaseCacheManager? cacheManager,
}) {
  return ResizeImage(
    CachedNetworkImageProvider(url, cacheManager: cacheManager),
    width: cacheEdge,
  );
}

typedef GalleryViewerPrecache = void Function(String url, int cacheEdge);

class GalleryViewer extends StatefulWidget {
  const GalleryViewer({
    super.key,
    required this.initialIndex,
    this.imageBuilder,
    this.onSetCover,
    this.onRemove,
    this.onPrecache,
  });

  final int initialIndex;
  final GalleryImageBuilder? imageBuilder;
  final ValueChanged<PixelfoxImage>? onSetCover;
  final ValueChanged<PixelfoxImage>? onRemove;
  final GalleryViewerPrecache? onPrecache;

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late final PageController _controller;
  late int _index;
  bool _zoomLocksPaging = false;
  int? _prefetchedIndex;
  int? _prefetchedLength;
  int? _prefetchedEdge;

  void _setZoomLock(bool locked) {
    if (!mounted || locked == _zoomLocksPaging) return;
    setState(() => _zoomLocksPaging = locked);
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _act(List<PixelfoxImage> items, ValueChanged<PixelfoxImage>? action) {
    if (action == null || items.isEmpty) return;
    final index = _index.clamp(0, items.length - 1);
    action(items[index]);
  }

  void _schedulePrefetch(int length, int cacheEdge) {
    if (_prefetchedIndex == _index &&
        _prefetchedLength == length &&
        _prefetchedEdge == cacheEdge) {
      return;
    }
    _prefetchedIndex = _index;
    _prefetchedLength = length;
    _prefetchedEdge = cacheEdge;
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheAhead());
  }

  void _precacheAhead() {
    if (!mounted) return;
    final callback = widget.onPrecache;
    if (callback == null && widget.imageBuilder != null) return;
    final items = context.read<GalleryService>().items;
    final edge = galleryViewerCacheEdge(
      viewportWidth: MediaQuery.sizeOf(context).width,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    for (final index in galleryViewerPrefetchIndexes(
      index: _index,
      length: items.length,
    )) {
      final url = items[index].stableUrl;
      if (callback != null) {
        callback(url, edge);
        continue;
      }
      final provider = galleryViewerImageProvider(
        url: url,
        cacheEdge: edge,
        cacheManager: galleryCacheManager(),
      );
      unawaited(precacheImage(provider, context, onError: (_, _) {}));
    }
  }

  /// Backup success can [GalleryService.refresh] and replace [GalleryService.items]
  /// while this route is still open.
  void _syncPageToItems() {
    if (!mounted) return;
    final items = context.read<GalleryService>().items;
    if (items.isEmpty) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (!_controller.hasClients) return;
    final page = _controller.page?.round() ?? widget.initialIndex;
    if (page >= items.length) {
      final last = items.length - 1;
      _controller.jumpToPage(last);
      if (_index != last) setState(() => _index = last);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<GalleryService>();
    final items = gallery.items;
    final s = context.l10n;
    final builder = widget.imageBuilder;

    final pagePastEnd =
        _controller.hasClients &&
        items.isNotEmpty &&
        (_controller.page?.round() ?? widget.initialIndex) >= items.length;
    if (items.isEmpty || pagePastEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPageToItems());
    }

    final cacheEdge = galleryViewerCacheEdge(
      viewportWidth: MediaQuery.sizeOf(context).width,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    _schedulePrefetch(items.length, cacheEdge);

    final showActions = widget.onSetCover != null || widget.onRemove != null;

    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: showActions
          ? SafeArea(
              child: ColoredBox(
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onSetCover != null)
                      IconButton(
                        tooltip: s.setAsCover,
                        onPressed: () => _act(items, widget.onSetCover),
                        icon: const Icon(
                          Icons.star_outline,
                          color: Colors.white,
                        ),
                      ),
                    if (widget.onRemove != null)
                      IconButton(
                        tooltip: s.removeFromAlbum,
                        onPressed: () => _act(items, widget.onRemove),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
      body: PageView.builder(
        controller: _controller,
        physics: _zoomLocksPaging
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: items.length,
        onPageChanged: (index) {
          setState(() => _index = index);
          if (index >= items.length - 3) {
            gallery.loadMore();
          }
        },
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const SizedBox.shrink();
          }
          final item = items[index];
          final image = builder != null
              ? builder(
                  url: item.stableUrl,
                  fit: BoxFit.contain,
                  memCacheWidth: cacheEdge,
                )
              : GalleryImage(
                  url: item.stableUrl,
                  fit: BoxFit.contain,
                  memCacheWidth: cacheEdge,
                  preview: false,
                  errorLabel: s.galleryImageLoadError,
                );
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: GalleryZoom(
              key: ValueKey(item.imageUuid),
              onZoomChanged: (zoomed) {
                if (index != _index) return;
                _setZoomLock(zoomed);
              },
              child: image,
            ),
          );
        },
      ),
    );
  }
}
