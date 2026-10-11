import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_brand.dart';
import '../models/backup_status.dart';
import '../models/pixelfox_image.dart';
import 'pixelfox_api_client.dart';
import 'storage.dart';

enum GallerySort {
  desc,
  asc;

  static GallerySort fromCode(String? code) => code == asc.name ? asc : desc;

  String? get requestValue => this == asc ? name : null;
}

class GalleryService extends ChangeNotifier {
  GalleryService({
    required this._clientProvider,
    this.albumId,
    this._prefs,
  });

  final PixelfoxApiClient Function() _clientProvider;
  final PrefsStore? _prefs;

  /// When set, pages are loaded with `album_id`.
  final int? albumId;

  List<PixelfoxImage> _items = [];
  bool _hasMore = false;
  String? _nextCursor;
  bool _loaded = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _snackMessage;
  GallerySort _order = GallerySort.desc;
  bool _orderReady = false;
  Future<void>? _orderLoad;
  int _epoch = 0;

  List<PixelfoxImage> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  String? get snackMessage => _snackMessage;
  GallerySort get order => _order;

  void clearSnack() {
    if (_snackMessage == null) return;
    _snackMessage = null;
    notifyListeners();
  }

  Future<void> _loadSavedOrder() {
    if (_orderReady || _prefs == null) {
      _orderReady = true;
      return Future<void>.value();
    }
    return _orderLoad ??= _readSavedOrder();
  }

  Future<void> _readSavedOrder() async {
    final raw = await _prefs!.getString(AppBrand.current.gallerySortPrefsKey);
    if (_orderReady) return;
    _order = GallerySort.fromCode(raw);
    _orderReady = true;
  }

  Future<void> ensureLoaded() async {
    await _loadSavedOrder();
    if (_loaded || _loading) return;
    await refresh();
  }

  Future<void> refresh() async {
    await _loadSavedOrder();
    if (_loading || _loadingMore) return;
    final epoch = _epoch;
    _loading = true;
    notifyListeners();
    await _fetchPage(epoch: epoch, append: false);
  }

  Future<void> loadMore() async {
    await _loadSavedOrder();
    if (!_hasMore || _loading || _loadingMore) return;
    final epoch = _epoch;
    _loadingMore = true;
    notifyListeners();
    await _fetchPage(epoch: epoch, append: true);
  }

  Future<void> setOrder(GallerySort order) async {
    await _loadSavedOrder();
    if (_order == order) return;
    _order = order;
    // Cursor is only valid for the sort that produced it.
    final epoch = ++_epoch;
    _items = [];
    _nextCursor = null;
    _hasMore = false;
    _error = null;
    _snackMessage = null;
    _loaded = false;
    _loading = true;
    _loadingMore = false;
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(AppBrand.current.gallerySortPrefsKey, order.name);
    }
    if (epoch != _epoch) return;
    await _fetchPage(epoch: epoch, append: false);
  }

  Future<void> _fetchPage({required int epoch, required bool append}) async {
    try {
      final page = await _clientProvider().listImages(
        cursor: append ? _nextCursor : null,
        albumId: albumId,
        sort: _order.requestValue,
      );
      if (epoch != _epoch) return;
      _items = append ? [..._items, ...page.items] : page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loaded = true;
      _error = null;
      _snackMessage = null;
    } catch (e) {
      if (epoch != _epoch) return;
      final message = e is PixelfoxApiException ? e.message : e.toString();
      if (append || _loaded) {
        _snackMessage = message;
      } else {
        _error = message;
      }
    }
    if (epoch != _epoch) return;
    _loading = false;
    _loadingMore = false;
    notifyListeners();
  }

  /// Drops one image from the loaded page without a network call.
  void forget(String imageUuid) {
    final next = _items.where((item) => item.imageUuid != imageUuid).toList();
    if (next.length == _items.length) return;
    _items = next;
    notifyListeners();
  }

  void onBackupPhaseChanged(BackupPhase previous, BackupPhase next) {
    if (previous == BackupPhase.working &&
        next == BackupPhase.success &&
        _loaded) {
      unawaited(refresh());
    }
  }
}
