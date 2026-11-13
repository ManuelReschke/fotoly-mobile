import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';
import '../services/file_scanner.dart';
import '../widgets/gallery_zoom.dart';
import '../widgets/local_file_image_stub.dart'
    if (dart.library.io) '../widgets/local_file_image_io.dart';
import '../widgets/local_file_thumbnail.dart';
import 'gallery_viewer.dart';

/// Fullscreen preview of local backup photos.
///
/// Opens from the backup thumbnail grid. A tap closes it, a swipe moves
/// through [files], and a pinch zooms the current photo.
class LocalFileViewer extends StatefulWidget {
  const LocalFileViewer({
    super.key,
    required this.files,
    required this.initialIndex,
  });

  final List<LocalImageFile> files;
  final int initialIndex;

  static void open(
    BuildContext context, {
    required List<LocalImageFile> files,
    required int initialIndex,
  }) {
    if (files.isEmpty) return;
    final last = files.length - 1;
    final index = initialIndex < 0
        ? 0
        : (initialIndex > last ? last : initialIndex);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LocalFileViewer(
          files: List<LocalImageFile>.of(files),
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  State<LocalFileViewer> createState() => _LocalFileViewerState();
}

class _LocalFileViewerState extends State<LocalFileViewer> {
  /// Image taps stay ignored until the route has finished opening and this
  /// long has passed, so the second half of a double-tap cannot dismiss it.
  static const _imageTapSettle = Duration(milliseconds: 400);

  late final PageController _controller;
  late int _index;
  bool _zoomLocksPaging = false;
  bool _imageTapCloses = false;
  Timer? _settleTimer;
  Animation<double>? _routeAnimation;
  DateTime? _shownAt;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchRoute());
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _controller.dispose();
    super.dispose();
  }

  void _watchRoute() {
    if (!mounted) return;
    _shownAt = DateTime.now();
    final animation = ModalRoute.of(context)?.animation;
    _routeAnimation = animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _scheduleImageTap();
      return;
    }
    animation.addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _scheduleImageTap();
  }

  void _scheduleImageTap() {
    final shownAt = _shownAt ?? DateTime.now();
    final remaining = _imageTapSettle - DateTime.now().difference(shownAt);
    if (remaining <= Duration.zero) {
      _enableImageTap();
      return;
    }
    _settleTimer = Timer(remaining, _enableImageTap);
  }

  void _enableImageTap() {
    if (!mounted || _imageTapCloses) return;
    setState(() => _imageTapCloses = true);
  }

  void _setZoomLock(bool locked) {
    if (!mounted || locked == _zoomLocksPaging) return;
    setState(() => _zoomLocksPaging = locked);
  }

  void _close() {
    Navigator.of(context).pop();
  }

  void _closeFromImage() {
    if (!_imageTapCloses) return;
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final files = widget.files;
    if (files.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final index = _index.clamp(0, files.length - 1);
    final cacheEdge = galleryViewerCacheEdge(
      viewportWidth: MediaQuery.sizeOf(context).width,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: _zoomLocksPaging
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: files.length,
            onPageChanged: (next) => setState(() => _index = next),
            itemBuilder: (context, page) {
              final file = files[page];
              return GestureDetector(
                onTap: _closeFromImage,
                child: GalleryZoom(
                  key: ValueKey(file.path),
                  onZoomChanged: (zoomed) {
                    if (page != _index) return;
                    _setZoomLock(zoomed);
                  },
                  child: localFileImage(
                    path: file.path,
                    cacheWidth: cacheEdge,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    placeholder: const LocalFileThumbnailPlaceholder(),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: s.closePhotoPreview,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x99000000),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    files[index].name,
                    key: const Key('localFilePreviewName'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
