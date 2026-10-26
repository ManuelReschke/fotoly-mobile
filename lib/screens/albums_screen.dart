import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../l10n/album_error_l10n.dart';
import '../l10n/l10n_scope.dart';
import '../l10n/user_error_l10n.dart';
import '../models/pixelfox_album.dart';
import '../services/album_service.dart';
import '../services/backup_service.dart';
import '../services/gallery_service.dart';
import '../widgets/album_editor_sheet.dart';
import '../widgets/gallery_image.dart';
import '../widgets/pixelfox_logo.dart';
import 'album_detail_screen.dart';
import 'settings_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key, this.imageBuilder});

  final GalleryImageBuilder? imageBuilder;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AlbumService>().ensureLoaded();
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _maybeShowSnack(AlbumService albums) {
    final message = albums.snackMessage;
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (albums.snackMessage != message) return;
      final s = context.l10nRead;
      _snack(localizeUserError(s, message, fallback: s.couldNotLoadAlbums));
      albums.clearSnack();
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

  Future<void> _create() async {
    final input = await showAlbumEditorSheet(context: context);
    if (!mounted || input == null) return;
    final s = context.l10nRead;
    try {
      await context.read<AlbumService>().create(input);
      _snack(s.albumCreated);
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumSaveError));
    }
  }

  void _openAlbum(PixelfoxAlbum album) {
    final albums = context.read<AlbumService>();
    final gallery = context.read<GalleryService>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AlbumService>.value(value: albums),
            ChangeNotifierProvider<GalleryService>.value(value: gallery),
          ],
          child: AlbumDetailScreen(
            albumId: album.id,
            imageBuilder: widget.imageBuilder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final albums = context.watch<AlbumService>();
    _maybeShowSnack(albums);
    return Scaffold(
      appBar: AppBar(
        title: PixelfoxBrandTitle(label: s.albumsTitle),
        actions: [
          IconButton(
            tooltip: s.albumsRefreshTooltip,
            icon: const Icon(Icons.refresh),
            onPressed: albums.loading ? null : albums.refresh,
          ),
          IconButton(
            tooltip: s.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('albums-create'),
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(s.createAlbum),
      ),
      body: _body(context, albums),
    );
  }

  Widget _body(BuildContext context, AlbumService albums) {
    final s = context.l10n;
    if (!albums.loaded) {
      if (albums.error != null && !albums.loading) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizeUserError(
                    s,
                    albums.error,
                    fallback: s.couldNotLoadAlbums,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: albums.refresh, child: Text(s.retry)),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (albums.albums.isEmpty) {
      return RefreshIndicator(
        onRefresh: albums.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.albumsEmptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(s.albumsEmptyBody, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: albums.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: albums.albums.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final album = albums.albums[index];
          final visibility = album.isPublic ? s.publicAlbum : s.privateAlbum;
          return ListTile(
            key: ValueKey('album-${album.id}'),
            leading: _coverLeading(album),
            title: Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${s.imagesCount(album.imageCount)} · $visibility'),
            trailing: album.isNsfw
                ? Text(
                    s.nsfwBadge,
                    style: Theme.of(context).textTheme.labelSmall,
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _openAlbum(album),
          );
        },
      ),
    );
  }

  Widget _coverLeading(PixelfoxAlbum album) {
    final raw = album.coverStableUrl;
    if (raw == null || raw.isEmpty) {
      return const Icon(Icons.photo_album_outlined);
    }
    final url = ApiConfig.absolute(raw)?.toString() ?? raw;
    final builder = widget.imageBuilder;
    final image = builder != null
        ? builder(url: url, fit: BoxFit.cover)
        : GalleryImage(url: url, fit: BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 56, height: 56, child: image),
    );
  }
}
