import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n_scope.dart';
import '../models/pixelfox_image.dart';
import 'gallery_image.dart';

typedef AlbumImagePageLoader =
    Future<PixelfoxImagePage> Function({String? cursor});

/// Multi-select library images. Returns chosen UUIDs, or null if dismissed.
Future<List<String>?> showAddAlbumImagesSheet({
  required BuildContext context,
  required AlbumImagePageLoader loadPage,
  required Set<String> alreadyInAlbum,
  GalleryImageBuilder? imageBuilder,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _AddAlbumImagesBody(
        loadPage: loadPage,
        alreadyInAlbum: alreadyInAlbum,
        imageBuilder: imageBuilder,
      ),
    ),
  );
}

class _AddAlbumImagesBody extends StatefulWidget {
  const _AddAlbumImagesBody({
    required this.loadPage,
    required this.alreadyInAlbum,
    this.imageBuilder,
  });

  final AlbumImagePageLoader loadPage;
  final Set<String> alreadyInAlbum;
  final GalleryImageBuilder? imageBuilder;

  @override
  State<_AddAlbumImagesBody> createState() => _AddAlbumImagesBodyState();
}

class _AddAlbumImagesBodyState extends State<_AddAlbumImagesBody> {
  final List<PixelfoxImage> _items = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _cursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (!_hasMore || _loadingMore)) return;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await widget.loadPage(cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _toggle(PixelfoxImage image) {
    if (widget.alreadyInAlbum.contains(image.imageUuid)) return;
    final s = context.l10nRead;
    setState(() {
      if (_selected.contains(image.imageUuid)) {
        _selected.remove(image.imageUuid);
      } else if (_selected.length >= 100) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.selectedCount(100))));
      } else {
        _selected.add(image.imageUuid);
      }
    });
  }

  Widget _thumb(PixelfoxImage image, int memCacheWidth) {
    final builder = widget.imageBuilder;
    if (builder != null) {
      return builder(
        url: image.stableUrl,
        fit: BoxFit.cover,
        memCacheWidth: memCacheWidth,
      );
    }
    return GalleryImage(
      url: image.stableUrl,
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.addExistingPhotos,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(s.selectedCount(_selected.length)),
          const SizedBox(height: 12),
          Expanded(child: _body(context, s)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
            child: Text(s.addToAlbum),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppStrings s) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.galleryLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _load(reset: true),
              child: Text(s.retry),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(s.albumPhotosEmptyTitle));
    }
    final memCacheWidth =
        (MediaQuery.sizeOf(context).width /
                3 *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    final extra = (_hasMore || _loadingMore) ? 1 : 0;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _items.length + extra,
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          if (_loadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: TextButton(
              onPressed: () => _load(reset: false),
              child: Text(s.loadMore),
            ),
          );
        }
        final image = _items[index];
        final already = widget.alreadyInAlbum.contains(image.imageUuid);
        final selected = already || _selected.contains(image.imageUuid);
        return GestureDetector(
          key: ValueKey(image.imageUuid),
          onTap: () => _toggle(image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: already ? 0.45 : 1,
                child: _thumb(image, memCacheWidth),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(Icons.check_circle, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}
