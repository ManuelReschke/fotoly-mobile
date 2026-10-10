import 'package:flutter/material.dart';

import '../l10n/album_error_l10n.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_scope.dart';
import '../models/album_sharing.dart';

/// Pick the full category set for one album and create private categories.
///
/// [initialAssigned] is null until this session has saved categories for the
/// album. The API cannot return the current assignment.
Future<void> showAlbumCategoriesSheet({
  required BuildContext context,
  required bool albumIsPublic,
  required List<AlbumCategory>? initialAssigned,
  required Future<List<AlbumCategory>> Function() load,
  required Future<AlbumCategory> Function(String name) create,
  required Future<List<AlbumCategory>> Function({
    required List<int> privateCategoryIds,
    required List<int> publicCategoryIds,
  })
  save,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _AlbumCategoriesBody(
      albumIsPublic: albumIsPublic,
      initialAssigned: initialAssigned,
      load: load,
      create: create,
      save: save,
    ),
  );
}

class _AlbumCategoriesBody extends StatefulWidget {
  const _AlbumCategoriesBody({
    required this.albumIsPublic,
    required this.initialAssigned,
    required this.load,
    required this.create,
    required this.save,
  });

  final bool albumIsPublic;
  final List<AlbumCategory>? initialAssigned;
  final Future<List<AlbumCategory>> Function() load;
  final Future<AlbumCategory> Function(String name) create;
  final Future<List<AlbumCategory>> Function({
    required List<int> privateCategoryIds,
    required List<int> publicCategoryIds,
  })
  save;

  @override
  State<_AlbumCategoriesBody> createState() => _AlbumCategoriesBodyState();
}

class _AlbumCategoriesBodyState extends State<_AlbumCategoriesBody> {
  final TextEditingController _name = TextEditingController();
  final List<AlbumCategory> _categories = [];
  final Set<int> _selected = {};
  Set<int> _initial = {};
  bool _loading = true;
  bool _working = false;
  bool _assignmentKnown = false;
  String? _error;
  String? _notice;
  String? _nameError;

  bool get _known => _assignmentKnown;

  bool get _dirty {
    if (_selected.length != _initial.length) return true;
    return !_selected.containsAll(_initial);
  }

  @override
  void initState() {
    super.initState();
    _assignmentKnown = widget.initialAssigned != null;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _allowed(AlbumCategory category) =>
      !category.isPublic || widget.albumIsPublic;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await widget.load();
      if (!mounted) return;
      final knownIds = widget.initialAssigned?.map((item) => item.id).toSet();
      setState(() {
        _categories
          ..clear()
          ..addAll(categories);
        _selected.clear();
        if (knownIds != null) {
          for (final category in categories) {
            if (knownIds.contains(category.id) && _allowed(category)) {
              _selected.add(category.id);
            }
          }
        }
        _initial = Set<int>.of(_selected);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final s = context.l10nRead;
      setState(() {
        _loading = false;
        _error = localizeAlbumSharingError(
          s,
          error,
          fallback: s.albumCategoryLoadError,
        );
      });
    }
  }

  Future<void> _create() async {
    if (_working) return;
    final s = context.l10nRead;
    final issue = albumCategoryNameIssue(_name.text);
    if (issue != null) {
      setState(() => _nameError = _nameMessage(s, issue));
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _nameError = null;
    });
    try {
      final created = await widget.create(_name.text.trim());
      if (!mounted) return;
      setState(() {
        _working = false;
        _name.clear();
        _categories.removeWhere((item) => item.id == created.id);
        _categories.insert(0, created);
        if (_selected.length < AlbumCategory.maxPerAlbum) {
          _selected.add(created.id);
        }
        _notice = s.albumCategoryCreated;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = localizeAlbumSharingError(
          s,
          error,
          fallback: s.albumCategoryCreateError,
        );
      });
    }
  }

  Future<void> _save({bool clear = false}) async {
    if (_working) return;
    final s = context.l10nRead;
    final selection = clear ? <int>{} : _selected;
    if (selection.length > AlbumCategory.maxPerAlbum) {
      setState(() => _error = s.albumCategoryTooMany);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.albumCategoryReplaceTitle),
        content: Text(s.albumCategoryReplaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancelAction),
          ),
          FilledButton(
            key: const Key('album-category-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.albumCategorySave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final privateIds = <int>[];
    final publicIds = <int>[];
    for (final category in _categories) {
      if (!selection.contains(category.id) || !_allowed(category)) continue;
      if (category.isPublic) {
        publicIds.add(category.id);
      } else {
        privateIds.add(category.id);
      }
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final saved = await widget.save(
        privateCategoryIds: privateIds,
        publicCategoryIds: publicIds,
      );
      if (!mounted) return;
      setState(() {
        _working = false;
        _selected
          ..clear()
          ..addAll(
            saved
                .where(_allowed)
                .map((category) => category.id)
                .where((id) => _categories.any((item) => item.id == id)),
          );
        if (clear) _selected.clear();
        _initial = Set<int>.of(_selected);
        _assignmentKnown = true;
        _notice = s.albumCategorySaved;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = localizeAlbumSharingError(
          s,
          error,
          fallback: s.albumCategorySaveError,
        );
      });
    }
  }

  String _nameMessage(AppStrings s, String issue) {
    switch (issue) {
      case 'too_long':
        return s.albumCategoryNameTooLong;
      case 'charset':
        return s.albumCategoryNameInvalid;
      default:
        return s.albumCategoryNameRequired;
    }
  }

  void _toggle(AlbumCategory category, bool selected) {
    setState(() {
      _notice = null;
      if (selected) {
        if (_selected.length >= AlbumCategory.maxPerAlbum) {
          _error = context.l10nRead.albumCategoryTooMany;
          return;
        }
        _selected.add(category.id);
      } else {
        _selected.remove(category.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final media = MediaQuery.of(context);
    final height = (media.size.height * 0.85 - media.viewInsets.bottom).clamp(
      280.0,
      media.size.height,
    );
    final canClear = _known
        ? _initial.isNotEmpty || _selected.isNotEmpty
        : true;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                s.albumCategories,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _known
                    ? s.albumCategoriesKnownHelp
                    : s.albumCategoriesUnknownHelp,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 8),
                Text(_notice!),
              ],
              const SizedBox(height: 8),
              Expanded(child: _categoryList(s)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('album-category-name'),
                controller: _name,
                decoration: InputDecoration(
                  labelText: s.albumCategoryNameLabel,
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 8),
              OverflowBar(
                spacing: 8,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('album-category-create'),
                    onPressed: _working ? null : _create,
                    child: Text(s.albumCategoryCreate),
                  ),
                  TextButton(
                    key: const Key('album-category-clear'),
                    onPressed: _working || !canClear
                        ? null
                        : () => _save(clear: true),
                    child: Text(s.albumCategoryClear),
                  ),
                  FilledButton(
                    key: const Key('album-category-save'),
                    onPressed: _working || !_dirty ? null : () => _save(),
                    child: Text(s.albumCategorySave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryList(AppStrings s) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_categories.isEmpty && _error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text(s.retry)),
      );
    }
    if (_categories.isEmpty) return Center(child: Text(s.albumCategoriesEmpty));
    final private = _categories.where((item) => !item.isPublic);
    final public = _categories.where((item) => item.isPublic);
    return ListView(
      children: [
        if (private.isNotEmpty) ...[
          Text(s.albumCategoryPrivate),
          for (final category in private) _tile(s, category),
        ],
        if (public.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(s.albumCategoryPublic),
          for (final category in public) _tile(s, category),
        ],
      ],
    );
  }

  Widget _tile(AppStrings s, AlbumCategory category) {
    final allowed = _allowed(category);
    return CheckboxListTile(
      key: Key('album-category-${category.id}'),
      contentPadding: EdgeInsets.zero,
      value: _selected.contains(category.id),
      onChanged: !allowed || _working
          ? null
          : (value) => _toggle(category, value ?? false),
      title: Text(category.name),
      subtitle: Text(
        allowed
            ? s.albumCategoryCount(category.albumCount)
            : s.albumCategoryPublicNeedsAlbum,
      ),
    );
  }
}
