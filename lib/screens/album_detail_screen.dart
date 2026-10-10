import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../l10n/album_error_l10n.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_scope.dart';
import '../models/pixelfox_album.dart';
import '../models/pixelfox_image.dart';
import '../services/album_file_picker.dart';
import '../services/album_service.dart';
import '../services/auth_service.dart';
import '../services/gallery_service.dart';
import '../services/pixelfox_api_client.dart';
import '../widgets/add_album_images_sheet.dart';
import '../widgets/album_categories_sheet.dart';
import '../widgets/album_editor_sheet.dart';
import '../widgets/album_members_sheet.dart';
import '../widgets/gallery_image.dart';
import 'gallery_viewer.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    this.imageBuilder,
    this.photos,
    this.pickFiles,
  });

  final int albumId;
  final GalleryImageBuilder? imageBuilder;

  /// Prebuilt photo list, used by tests. The screen owns and disposes a
  /// private [GalleryService] when this is null.
  final GalleryService? photos;

  final Future<List<AlbumUploadFile>> Function()? pickFiles;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  GalleryService? _ownedPhotos;
  GalleryService? _photos;
  bool _busy = false;

  GalleryService? get photos => _photos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_photos != null) return;
    final provided = widget.photos;
    if (provided != null) {
      _photos = provided;
    } else {
      final auth = context.read<AuthService>();
      _ownedPhotos = GalleryService(
        albumId: widget.albumId,
        clientProvider: () {
          final client = auth.client;
          if (client == null) throw StateError('Not authenticated');
          return client;
        },
      );
      _photos = _ownedPhotos;
    }
    _photos!.addListener(_onPhotos);
    _photos!.ensureLoaded();
  }

  void _onPhotos() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _photos?.removeListener(_onPhotos);
    _ownedPhotos?.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  PixelfoxApiClient? _client() => context.read<AuthService>().client;

  Future<void> _edit(PixelfoxAlbum album) async {
    final input = await showAlbumEditorSheet(context: context, album: album);
    if (!mounted || input == null) return;
    final s = context.l10nRead;
    try {
      await context.read<AlbumService>().update(album.id, input);
      _snack(s.albumSaved);
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumSaveError));
    }
  }

  Future<void> _members(PixelfoxAlbum album) {
    final albums = context.read<AlbumService>();
    return showAlbumMembersSheet(
      context: context,
      load: () => albums.members(album.id),
      invite: ({userId, username}) =>
          albums.inviteMember(album.id, userId: userId, username: username),
      remove: (userId) => albums.removeMember(album.id, userId),
    );
  }

  Future<void> _categories(PixelfoxAlbum album) {
    final albums = context.read<AlbumService>();
    return showAlbumCategoriesSheet(
      context: context,
      albumIsPublic: album.isPublic,
      initialAssigned: albums.assignedCategories(album.id),
      load: albums.listCategories,
      create: albums.createCategory,
      save:
          ({
            required List<int> privateCategoryIds,
            required List<int> publicCategoryIds,
          }) => albums.setCategories(
            album.id,
            privateCategoryIds: privateCategoryIds,
            publicCategoryIds: publicCategoryIds,
          ),
    );
  }

  Future<void> _delete(PixelfoxAlbum album) async {
    final s = context.l10nRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAlbumTitle),
        content: Text(s.deleteAlbumBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.deleteAlbum),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AlbumService>().delete(album.id);
      if (!mounted) return;
      _snack(s.albumDeleted);
      Navigator.of(context).pop();
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumDeleteError));
    }
  }

  Future<void> _copyLink(PixelfoxAlbum album) async {
    final s = context.l10nRead;
    final uri = ApiConfig.absolute(album.viewUrl);
    if (uri == null) {
      _snack(s.albumCouldNotOpenLink);
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    _snack(s.albumLinkCopied);
  }

  Future<void> _openLink(PixelfoxAlbum album) async {
    final s = context.l10nRead;
    final uri = ApiConfig.absolute(album.viewUrl);
    if (uri == null) {
      _snack(s.albumCouldNotOpenLink);
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _snack(s.albumCouldNotOpenLink);
  }

  Future<void> _setCover(PixelfoxImage image) async {
    final s = context.l10nRead;
    final client = _client();
    if (client == null) return;
    try {
      final updated = await client.setAlbumCover(
        widget.albumId,
        imageUuid: image.imageUuid,
      );
      if (!mounted) return;
      context.read<AlbumService>().remember(updated);
      _snack(s.coverUpdated);
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumActionError));
    }
  }

  Future<void> _clearCover() async {
    final s = context.l10nRead;
    final client = _client();
    if (client == null) return;
    try {
      final updated = await client.setAlbumCover(widget.albumId, imageUuid: '');
      if (!mounted) return;
      context.read<AlbumService>().remember(
        updated.copyWith(clearCover: updated.coverImageUuid == null),
      );
      _snack(s.coverUpdated);
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumActionError));
    }
  }

  Future<void> _remove(PixelfoxImage image) async {
    final s = context.l10nRead;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.removeFromAlbum),
        content: Text(s.removeFromAlbumBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.removeFromAlbum),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final client = _client();
    if (client == null) return;
    try {
      await client.removeImageFromAlbum(widget.albumId, image.imageUuid);
      if (!mounted) return;
      _photos?.forget(image.imageUuid);
      final albums = context.read<AlbumService>();
      final current = albums.byId(widget.albumId);
      if (current != null) {
        final nextCount = current.imageCount > 0 ? current.imageCount - 1 : 0;
        albums.remember(
          current.copyWith(
            imageCount: nextCount,
            clearCover: current.coverImageUuid == image.imageUuid,
          ),
        );
      }
      _snack(s.photoRemoved);
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumActionError));
    }
  }

  Future<void> _upload(PixelfoxAlbum album) async {
    if (_busy) return;
    final s = context.l10nRead;
    final pick = widget.pickFiles ?? pickAlbumUploadFiles;
    final picked = await pick();
    if (!mounted || picked.isEmpty) return;
    final client = _client();
    if (client == null) return;
    setState(() => _busy = true);
    var uploaded = 0;
    var failed = 0;
    try {
      for (final file in picked) {
        try {
          await client.uploadImageBytes(
            filename: file.filename,
            bytes: file.bytes,
            albumId: album.id,
            isNsfw: album.isNsfw ? true : null,
          );
          uploaded++;
        } catch (_) {
          failed++;
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (uploaded > 0) {
      await _photos?.refresh();
      if (!mounted) return;
      final gallery = context.read<GalleryService>();
      if (gallery.loaded && !identical(gallery, _photos)) {
        await gallery.refresh();
      }
      if (!mounted) return;
      final current = context.read<AlbumService>().byId(album.id);
      if (current != null) {
        context.read<AlbumService>().setImageCount(
          album.id,
          current.imageCount + uploaded,
        );
      }
    }
    _snack(s.uploadFinished(uploaded: uploaded, failed: failed));
  }

  Future<void> _addExisting() async {
    final s = context.l10nRead;
    final client = _client();
    final loaded = _photos;
    if (client == null || loaded == null) return;
    final selected = await showAddAlbumImagesSheet(
      context: context,
      loadPage: ({cursor}) => client.listImages(cursor: cursor),
      alreadyInAlbum: loaded.items.map((item) => item.imageUuid).toSet(),
      imageBuilder: widget.imageBuilder,
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    try {
      final result = await client.addImagesToAlbum(widget.albumId, selected);
      if (!mounted) return;
      context.read<AlbumService>().setImageCount(
        widget.albumId,
        result.imageCount,
      );
      await loaded.refresh();
      _snack(s.photosAdded(result.added.length));
    } catch (e) {
      _snack(localizeAlbumError(s, e, fallback: s.albumActionError));
    }
  }

  Future<void> _addMenu(PixelfoxAlbum album) async {
    final s = context.l10nRead;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: Text(s.uploadNewPhotos),
              onTap: () => Navigator.pop(ctx, 'upload'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(s.addExistingPhotos),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'upload') {
      await _upload(album);
    } else {
      await _addExisting();
    }
  }

  void _openViewer(int index) {
    final gallery = _photos;
    if (gallery == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<GalleryService>.value(
          value: gallery,
          child: GalleryViewer(
            initialIndex: index,
            imageBuilder: widget.imageBuilder,
            onSetCover: (image) {
              Navigator.of(context).pop();
              _setCover(image);
            },
            onRemove: (image) {
              Navigator.of(context).pop();
              _remove(image);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _imageMenu(PixelfoxImage image) async {
    final s = context.l10nRead;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: Text(s.setAsCover),
              onTap: () => Navigator.pop(ctx, 'cover'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(s.removeFromAlbum),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'cover') {
      await _setCover(image);
    } else {
      await _remove(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final albums = context.watch<AlbumService>();
    final album = albums.byId(widget.albumId);
    final photos = _photos;
    _maybePhotoSnack(photos);

    return Scaffold(
      appBar: AppBar(
        title: Text(album?.title ?? s.albumsTitle),
        actions: [
          if (album != null)
            PopupMenuButton<String>(
              tooltip: s.albumActionsTooltip,
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    unawaited(_edit(album));
                  case 'members':
                    unawaited(_members(album));
                  case 'categories':
                    unawaited(_categories(album));
                  case 'copy':
                    unawaited(_copyLink(album));
                  case 'open':
                    unawaited(_openLink(album));
                  case 'cover':
                    unawaited(_clearCover());
                  case 'delete':
                    unawaited(_delete(album));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(s.editAlbum)),
                PopupMenuItem(
                  key: const Key('album-action-members'),
                  value: 'members',
                  child: Text(s.albumMembers),
                ),
                PopupMenuItem(
                  key: const Key('album-action-categories'),
                  value: 'categories',
                  child: Text(s.albumCategories),
                ),
                if (album.viewUrl.isNotEmpty) ...[
                  PopupMenuItem(value: 'copy', child: Text(s.copyAlbumLink)),
                  PopupMenuItem(value: 'open', child: Text(s.openAlbumLink)),
                ],
                if (album.coverImageUuid != null)
                  PopupMenuItem(value: 'cover', child: Text(s.clearCover)),
                PopupMenuItem(value: 'delete', child: Text(s.deleteAlbum)),
              ],
            ),
        ],
      ),
      floatingActionButton: album == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _addMenu(album),
              icon: const Icon(Icons.add),
              label: Text(s.addPhotos),
            ),
      body: _withBusy(
        album == null
            ? _missing(s, albums)
            : _content(context, s, album, photos),
        s,
      ),
    );
  }

  void _maybePhotoSnack(GalleryService? photos) {
    final message = photos?.snackMessage;
    if (message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || photos!.snackMessage != message) return;
      _snack(message);
      photos.clearSnack();
    });
  }

  Widget _withBusy(Widget child, AppStrings s) {
    if (!_busy) return child;
    return Stack(
      children: [
        child,
        const ModalBarrier(dismissible: false, color: Color(0x66000000)),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(s.uploadingPhotos),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _missing(AppStrings s, AlbumService albums) {
    if (!albums.loaded || albums.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: Text(s.albumNotFound));
  }

  Widget _content(
    BuildContext context,
    AppStrings s,
    PixelfoxAlbum album,
    GalleryService? photos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(album.isPublic ? s.publicAlbum : s.privateAlbum),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(s.imagesCount(album.imageCount)),
                visualDensity: VisualDensity.compact,
              ),
              if (album.isNsfw)
                Chip(
                  label: Text(s.nsfwBadge),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (album.description.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(album.description),
          ),
        Expanded(child: _grid(context, s, album, photos)),
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    AppStrings s,
    PixelfoxAlbum album,
    GalleryService? photos,
  ) {
    if (photos == null || (!photos.loaded && photos.error == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (photos.error != null && photos.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                photos.error ?? s.galleryLoadError,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: photos.refresh, child: Text(s.retry)),
            ],
          ),
        ),
      );
    }
    if (photos.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: photos.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.albumPhotosEmptyTitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(s.albumPhotosEmptyBody, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final items = photos.items;
    final memCacheWidth =
        (MediaQuery.sizeOf(context).width /
                3 *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return RefreshIndicator(
      onRefresh: photos.refresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: items.length + (photos.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          if (photos.hasMore && index >= items.length - 8) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              photos.loadMore();
            });
          }
          final item = items[index];
          final isCover = album.coverImageUuid == item.imageUuid;
          return GestureDetector(
            key: ValueKey(item.imageUuid),
            onTap: () => _openViewer(index),
            onLongPress: () => _imageMenu(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _tile(item.stableUrl, memCacheWidth),
                if (isCover)
                  const Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(Icons.star, color: Colors.amber, size: 18),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(String url, int memCacheWidth) {
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
}
