import 'package:flutter/foundation.dart';

import '../models/album_sharing.dart';
import '../models/pixelfox_album.dart';
import 'pixelfox_api_client.dart';

class AlbumService extends ChangeNotifier {
  AlbumService({required this._clientProvider});

  final PixelfoxApiClient Function() _clientProvider;

  List<PixelfoxAlbum> _albums = [];
  bool _disposed = false;
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<T> _request<T>(Future<T> Function(PixelfoxApiClient) send) async {
    final client = _clientProvider();
    try {
      return await send(client);
    } finally {
      client.close();
    }
  }

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
    if (_disposed || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      final albums = await _request((client) => client.listAlbums());
      if (_disposed) return;
      _albums = albums;
      _loaded = true;
      _error = null;
      _snackMessage = null;
    } catch (e) {
      if (_disposed) return;
      final message = e is PixelfoxApiException ? e.message : e.toString();
      if (_loaded) {
        _snackMessage = message;
      } else {
        _error = message;
      }
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<PixelfoxAlbum> create(AlbumInput input) async {
    final created = await _request((client) => client.createAlbum(input));
    _upsert(created);
    return created;
  }

  Future<PixelfoxAlbum> update(int id, AlbumInput input) async {
    final updated = await _request((client) => client.updateAlbum(id, input));
    _upsert(updated);
    return updated;
  }

  Future<void> delete(int id) async {
    await _request((client) => client.deleteAlbum(id));
    if (_disposed) return;
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
    return _request((client) => client.listAlbumMembers(albumId));
  }

  Future<AlbumMemberInvite> inviteMember(
    int albumId, {
    int? userId,
    String? username,
    String? email,
  }) {
    return _request(
      (client) => client.inviteAlbumMember(
        albumId,
        userId: userId,
        username: username,
        email: email,
      ),
    );
  }

  Future<void> removeMember(int albumId, int userId) {
    return _request((client) => client.removeAlbumMember(albumId, userId));
  }

  Future<List<AlbumCategory>> listCategories() {
    return _request((client) => client.listAlbumCategories());
  }

  Future<AlbumCategory> createCategory(String name) {
    return _request((client) => client.createAlbumCategory(name));
  }

  Future<List<AlbumCategory>> setCategories(
    int albumId, {
    required List<int> privateCategoryIds,
    required List<int> publicCategoryIds,
  }) async {
    final selected = await _request(
      (client) => client.setAlbumCategories(
        albumId,
        privateCategoryIds: privateCategoryIds,
        publicCategoryIds: publicCategoryIds,
      ),
    );
    if (_disposed) return selected;
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
    if (_disposed) return;
    final next = _albums.where((item) => item.id != album.id).toList()
      ..add(album);
    next.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _albums = next;
    _loaded = true;
    _error = null;
    notifyListeners();
  }
}
