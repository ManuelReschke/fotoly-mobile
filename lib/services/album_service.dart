import 'package:flutter/foundation.dart';

import '../models/album_sharing.dart';
import '../models/pixelfox_album.dart';
import 'pixelfox_api_client.dart';

class AlbumService extends ChangeNotifier {
  AlbumService({required this._clientProvider});

  final PixelfoxApiClient Function() _clientProvider;

  List<PixelfoxAlbum> _albums = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  String? _snackMessage;

  /// Categories last saved in this session. The API has no read for them.
  final Map<int, List<AlbumCategory>> _assignedCategories = {};

  List<PixelfoxAlbum> get albums => List.unmodifiable(_albums);
  bool get loaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;
  String? get snackMessage => _snackMessage;

  PixelfoxAlbum? byId(int id) {
    for (final album in _albums) {
      if (album.id == id) return album;
    }
    return null;
  }

  void clearSnack() {
    if (_snackMessage == null) return;
    _snackMessage = null;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _albums = await _clientProvider().listAlbums();
      _loaded = true;
      _error = null;
      _snackMessage = null;
    } catch (e) {
      final message = e is PixelfoxApiException ? e.message : e.toString();
      if (_loaded) {
        _snackMessage = message;
      } else {
        _error = message;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<PixelfoxAlbum> create(AlbumInput input) async {
    final created = await _clientProvider().createAlbum(input);
    _upsert(created);
    return created;
  }

  Future<PixelfoxAlbum> update(int id, AlbumInput input) async {
    final updated = await _clientProvider().updateAlbum(id, input);
    final previous = byId(id);
    _upsert(
      previous?.coverImageUuid == null
          ? updated
          : updated.copyWith(coverImageUuid: previous!.coverImageUuid),
    );
    return byId(id) ?? updated;
  }

  Future<void> delete(int id) async {
    await _clientProvider().deleteAlbum(id);
    _albums = _albums.where((album) => album.id != id).toList();
    _assignedCategories.remove(id);
    notifyListeners();
  }

  void remember(PixelfoxAlbum album) => _upsert(album);

  /// Categories saved for [albumId] during this session, if any.
  List<AlbumCategory>? assignedCategories(int albumId) {
    final saved = _assignedCategories[albumId];
    if (saved == null) return null;
    return List.unmodifiable(saved);
  }

  Future<List<AlbumMember>> members(int albumId) {
    return _clientProvider().listAlbumMembers(albumId);
  }

  Future<AlbumMemberInvite> inviteMember(
    int albumId, {
    int? userId,
    String? username,
  }) {
    return _clientProvider().inviteAlbumMember(
      albumId,
      userId: userId,
      username: username,
    );
  }

  Future<void> removeMember(int albumId, int userId) {
    return _clientProvider().removeAlbumMember(albumId, userId);
  }

  Future<List<AlbumCategory>> listCategories() {
    return _clientProvider().listAlbumCategories();
  }

  Future<AlbumCategory> createCategory(String name) {
    return _clientProvider().createAlbumCategory(name);
  }

  Future<List<AlbumCategory>> setCategories(
    int albumId, {
    required List<int> privateCategoryIds,
    required List<int> publicCategoryIds,
  }) async {
    final selected = await _clientProvider().setAlbumCategories(
      albumId,
      privateCategoryIds: privateCategoryIds,
      publicCategoryIds: publicCategoryIds,
    );
    _assignedCategories[albumId] = selected;
    notifyListeners();
    return selected;
  }

  void setImageCount(int id, int count) {
    final current = byId(id);
    if (current == null || current.imageCount == count) return;
    _upsert(current.copyWith(imageCount: count));
  }

  void _upsert(PixelfoxAlbum album) {
    final next = _albums.where((item) => item.id != album.id).toList()
      ..add(album);
    next.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _albums = next;
    _loaded = true;
    _error = null;
    notifyListeners();
  }
}
