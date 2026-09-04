import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_scope.dart';
import '../services/gallery_service.dart';
import '../widgets/gallery_image.dart';

class GalleryViewer extends StatefulWidget {
  const GalleryViewer({
    super.key,
    required this.initialIndex,
    this.imageBuilder,
  });

  final int initialIndex;
  final GalleryImageBuilder? imageBuilder;

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      _controller.jumpToPage(items.length - 1);
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        itemCount: items.length,
        onPageChanged: (index) {
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
              ? builder(url: item.stableUrl, fit: BoxFit.contain)
              : GalleryImage(
                  url: item.stableUrl,
                  fit: BoxFit.contain,
                  errorLabel: s.galleryImageLoadError,
                );
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: image,
          );
        },
      ),
    );
  }
}
