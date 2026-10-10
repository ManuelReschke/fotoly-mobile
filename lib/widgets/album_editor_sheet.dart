import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';
import '../models/pixelfox_album.dart';

/// Create or edit album metadata. Returns null when dismissed.
Future<AlbumInput?> showAlbumEditorSheet({
  required BuildContext context,
  PixelfoxAlbum? album,
}) {
  return showModalBottomSheet<AlbumInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _AlbumEditorBody(album: album),
  );
}

class _AlbumEditorBody extends StatefulWidget {
  const _AlbumEditorBody({this.album});

  final PixelfoxAlbum? album;

  @override
  State<_AlbumEditorBody> createState() => _AlbumEditorBodyState();
}

class _AlbumEditorBodyState extends State<_AlbumEditorBody> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _password;
  late bool _isPublic;
  late bool _isNsfw;
  late String _sort;
  late bool _changePassword;
  String? _titleError;

  bool get _isEdit => widget.album != null;

  @override
  void initState() {
    super.initState();
    final album = widget.album;
    _title = TextEditingController(text: album?.title ?? '');
    _description = TextEditingController(text: album?.description ?? '');
    _password = TextEditingController();
    _isPublic = album?.isPublic ?? false;
    _isNsfw = album?.isNsfw ?? false;
    _sort = album?.imageSortOrder ?? PixelfoxAlbum.sortNewest;
    _changePassword = false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final s = context.l10nRead;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = s.albumTitleRequired);
      return;
    }
    if (title.characters.length > 255) {
      setState(() => _titleError = s.albumTitleRequired);
      return;
    }
    final description = _description.text.trim();
    String? sharePassword;
    if (!_isEdit) {
      final password = _password.text;
      if (password.isNotEmpty) sharePassword = password;
    } else if (_changePassword) {
      sharePassword = _password.text;
    }
    Navigator.of(context).pop(
      AlbumInput(
        title: title,
        description: description,
        isPublic: _isPublic,
        isNsfw: _isNsfw,
        imageSortOrder: _sort,
        sharePassword: sharePassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              _isEdit ? s.editAlbum : s.createAlbum,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEdit,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: s.albumTitleLabel,
                errorText: _titleError,
              ),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 10000,
              decoration: InputDecoration(labelText: s.albumDescriptionLabel),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.albumPublicLabel),
              subtitle: Text(s.albumPublicSubtitle),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.albumNsfwLabel),
              subtitle: Text(s.albumNsfwSubtitle),
              value: _isNsfw,
              onChanged: (value) => setState(() => _isNsfw = value),
            ),
            const SizedBox(height: 8),
            Text(
              s.albumSortLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(s.albumSortHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: PixelfoxAlbum.sortNewest,
                  label: Text(s.albumSortNewest),
                ),
                ButtonSegment(
                  value: PixelfoxAlbum.sortOldest,
                  label: Text(s.albumSortOldest),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (value) =>
                  setState(() => _sort = value.first),
            ),
            const SizedBox(height: 12),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.albumChangePassword),
                subtitle: Text(
                  widget.album!.hasSharePassword
                      ? s.albumPasswordClearHint
                      : s.albumPasswordHint,
                ),
                value: _changePassword,
                onChanged: (value) => setState(() => _changePassword = value),
              ),
            if (!_isEdit || _changePassword)
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.albumPasswordLabel,
                  helperText: _isEdit
                      ? s.albumPasswordClearHint
                      : s.albumPasswordHint,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('album-save'),
              onPressed: _save,
              child: Text(_isEdit ? s.albumSave : s.createAlbum),
            ),
          ],
        ),
      ),
    );
  }
}
