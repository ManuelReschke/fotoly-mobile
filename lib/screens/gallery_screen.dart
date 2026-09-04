import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_scope.dart';
import '../services/backup_service.dart';
import '../services/gallery_service.dart';
import '../widgets/gallery_image.dart';
import '../widgets/pixelfox_logo.dart';
import 'gallery_viewer.dart';
import 'settings_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.imageBuilder});

  final GalleryImageBuilder? imageBuilder;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GalleryService>().ensureLoaded();
    });
  }

  void _openSettings() {
    final backup = context.read<BackupService>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<BackupService>.value(
          value: backup,
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  void _openViewer(int index) {
    final gallery = context.read<GalleryService>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<GalleryService>.value(
          value: gallery,
          child: GalleryViewer(
            initialIndex: index,
            imageBuilder: widget.imageBuilder,
          ),
        ),
      ),
    );
  }

  void _maybeShowSnack(GalleryService gallery) {
    final message = gallery.snackMessage;
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (gallery.snackMessage != message) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      gallery.clearSnack();
    });
  }

  void _maybeLoadMore(GalleryService gallery, int index) {
    if (!gallery.hasMore || gallery.loading || gallery.loadingMore) return;
    if (index < gallery.items.length - 8) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gallery.loadMore();
    });
  }

  Widget _tileImage(BuildContext context, String url) {
    final memCacheWidth =
        (MediaQuery.sizeOf(context).width /
                3 *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    final builder = widget.imageBuilder;
    if (builder != null) {
      return builder(url: url, fit: BoxFit.cover, memCacheWidth: memCacheWidth);
    }
    return GalleryImage(
      url: url,
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final gallery = context.watch<GalleryService>();
    _maybeShowSnack(gallery);

    final refreshing = gallery.loading || gallery.loadingMore;

    return Scaffold(
      appBar: AppBar(
        title: PixelfoxBrandTitle(label: s.galleryTitle),
        actions: [
          IconButton(
            tooltip: s.galleryRefreshTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: refreshing ? null : gallery.refresh,
          ),
          IconButton(
            tooltip: s.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(context, gallery),
    );
  }

  Widget _buildBody(BuildContext context, GalleryService gallery) {
    final s = context.l10n;

    if (!gallery.loaded) {
      if (gallery.error != null && !gallery.loading) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gallery.error ?? s.galleryLoadError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: gallery.refresh, child: Text(s.retry)),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (gallery.loaded && gallery.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.galleryEmptyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(s.galleryEmptyBody, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final items = gallery.items;
    final itemCount = items.length + (gallery.loadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: gallery.refresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          _maybeLoadMore(gallery, index);
          final item = items[index];
          return GestureDetector(
            key: ValueKey(item.imageUuid),
            onTap: () => _openViewer(index),
            child: _tileImage(context, item.stableUrl),
          );
        },
      ),
    );
  }
}
