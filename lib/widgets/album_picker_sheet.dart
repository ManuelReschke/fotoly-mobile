import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';
import '../models/pixelfox_album.dart';
import '../theme/app_theme.dart';

/// Result of the album picker: null album = “no album”.
class AlbumPickResult {
  const AlbumPickResult({this.album});

  final PixelfoxAlbum? album;

  int? get albumId => album?.id;
  String? get albumTitle => album?.title;
}

/// Bottom sheet: pick a Pixelfox album (or none) for a local folder.
Future<AlbumPickResult?> showAlbumPickerSheet({
  required BuildContext context,
  required Future<List<PixelfoxAlbum>> Function() loadAlbums,
  required String folderPath,
  int? selectedAlbumId,
}) {
  return showModalBottomSheet<AlbumPickResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return _AlbumPickerBody(
        loadAlbums: loadAlbums,
        folderPath: folderPath,
        selectedAlbumId: selectedAlbumId,
      );
    },
  );
}

class _AlbumPickerBody extends StatefulWidget {
  const _AlbumPickerBody({
    required this.loadAlbums,
    required this.folderPath,
    this.selectedAlbumId,
  });

  final Future<List<PixelfoxAlbum>> Function() loadAlbums;
  final String folderPath;
  final int? selectedAlbumId;

  @override
  State<_AlbumPickerBody> createState() => _AlbumPickerBodyState();
}

class _AlbumPickerBodyState extends State<_AlbumPickerBody> {
  late Future<List<PixelfoxAlbum>> _future;
  List<PixelfoxAlbum> _albums = const [];
  int? _selectedId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedAlbumId;
    _future = widget.loadAlbums();
    _future
        .then((list) {
          if (!mounted) return;
          setState(() {
            _albums = list;
            _loaded = true;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        });
  }

  void _confirm() {
    PixelfoxAlbum? album;
    if (_selectedId != null) {
      for (final a in _albums) {
        if (a.id == _selectedId) {
          album = a;
          break;
        }
      }
    }
    Navigator.of(context).pop(AlbumPickResult(album: album));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.targetAlbumTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.targetAlbumSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.folderPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foxOrange,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: FutureBuilder<List<PixelfoxAlbum>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.foxOrange,
                            ),
                            const SizedBox(height: 12),
                            Text(s.loadingAlbums),
                          ],
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          s.couldNotLoadAlbums,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final albums = snap.data ?? const <PixelfoxAlbum>[];
                    return ListView(
                      children: [
                        _AlbumTile(
                          title: s.noAlbumOption,
                          subtitle: s.noAlbumHint,
                          selected: _selectedId == null,
                          icon: Icons.photo_library_outlined,
                          onTap: () => setState(() => _selectedId = null),
                        ),
                        ...albums.map(
                          (a) => _AlbumTile(
                            title: a.title.isEmpty ? '#${a.id}' : a.title,
                            subtitle: s.imagesCount(a.imageCount),
                            selected: _selectedId == a.id,
                            icon: Icons.collections_outlined,
                            onTap: () => setState(() => _selectedId = a.id),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loaded || _albums.isNotEmpty || _selectedId == null
                    ? _confirm
                    : null,
                child: Text(s.confirmFolder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.foxOrange.withValues(alpha: 0.12)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.foxOrange.withValues(alpha: 0.5)
                    : scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppTheme.foxOrange : scheme.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: AppTheme.foxOrange),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
