import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Minimum scale is a fitted photo. [kGalleryMaxZoom] is the pinch limit.
const double kGalleryMinZoom = 1;
const double kGalleryMaxZoom = 4;

/// Slack under which a pinch is treated as not zoomed, so paging stays usable.
const double kGalleryZoomSlack = 0.01;

/// Keeps [childFocal] under [focalPoint] while scaling from the top-left,
/// then clamps so the scaled child still covers [viewport].
@visibleForTesting
Offset galleryZoomOffset({
  required Offset focalPoint,
  required Offset childFocal,
  required double scale,
  required Size viewport,
}) {
  if (scale <= kGalleryMinZoom || viewport.width <= 0 || viewport.height <= 0) {
    return Offset.zero;
  }
  final raw = focalPoint - childFocal * scale;
  return Offset(
    raw.dx.clamp(viewport.width * (1 - scale), 0.0).toDouble(),
    raw.dy.clamp(viewport.height * (1 - scale), 0.0).toDouble(),
  );
}

/// Pinch-zoom and, once zoomed, one-finger pan for a gallery page.
///
/// One-finger drags are not claimed until the photo is zoomed in, so a parent
/// [PageView] can still swipe between photos.
class GalleryZoom extends StatefulWidget {
  const GalleryZoom({super.key, required this.child, this.onZoomChanged});

  final Widget child;

  /// Called when the photo crosses the zoomed / fitted boundary.
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<GalleryZoom> createState() => _GalleryZoomState();
}

class _GalleryZoomState extends State<GalleryZoom> {
  double _scale = kGalleryMinZoom;
  Offset _offset = Offset.zero;
  double _gestureStartScale = kGalleryMinZoom;
  Offset? _childFocal;
  bool _reportedZoom = false;

  bool get _zoomed => _scale > kGalleryMinZoom + kGalleryZoomSlack;

  Size get _viewport {
    final size = context.size;
    if (size == null || size.isEmpty) return Size.zero;
    return size;
  }

  void _publishZoom() {
    final zoomed = _zoomed;
    if (zoomed == _reportedZoom) return;
    _reportedZoom = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _childFocal = (details.localFocalPoint - _offset) / _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final childFocal = _childFocal;
    if (childFocal == null) return;
    final nextScale = (_gestureStartScale * details.scale)
        .clamp(kGalleryMinZoom, kGalleryMaxZoom)
        .toDouble();
    final nextOffset = galleryZoomOffset(
      focalPoint: details.localFocalPoint,
      childFocal: childFocal,
      scale: nextScale,
      viewport: _viewport,
    );
    setState(() {
      _scale = nextScale;
      _offset = nextOffset;
    });
    _publishZoom();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (details.pointerCount > 0) return;
    _childFocal = null;
    if (!_zoomed) {
      setState(() {
        _scale = kGalleryMinZoom;
        _offset = Offset.zero;
      });
    }
    _publishZoom();
  }

  @override
  void dispose() {
    if (_reportedZoom) {
      _reportedZoom = false;
      widget.onZoomChanged?.call(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              _GalleryScaleRecognizer:
                  GestureRecognizerFactoryWithHandlers<_GalleryScaleRecognizer>(
                    () => _GalleryScaleRecognizer(panAllowed: () => _zoomed),
                    (_GalleryScaleRecognizer recognizer) {
                      recognizer.gestureSettings =
                          MediaQuery.maybeGestureSettingsOf(context);
                      recognizer.onStart = _onScaleStart;
                      recognizer.onUpdate = _onScaleUpdate;
                      recognizer.onEnd = _onScaleEnd;
                    },
                  ),
            },
            child: ClipRect(
              child: Transform(
                alignment: Alignment.topLeft,
                filterQuality: _zoomed
                    ? FilterQuality.medium
                    : FilterQuality.none,
                transform: Matrix4.identity()
                  ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                  ..scaleByDouble(_scale, _scale, 1, 1),
                child: SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Claims a pinch immediately, and a one-finger drag only while [panAllowed]
/// is true. Otherwise the accept is dropped so a parent pager can win.
class _GalleryScaleRecognizer extends ScaleGestureRecognizer {
  _GalleryScaleRecognizer({required this.panAllowed});

  final bool Function() panAllowed;

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted &&
        !panAllowed() &&
        pointerCount < 2) {
      return;
    }
    super.resolve(disposition);
  }
}
