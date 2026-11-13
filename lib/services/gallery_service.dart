import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_brand.dart';
import '../models/backup_status.dart';
import '../models/pixelfox_image.dart';
import 'network_failure.dart';
import 'pixelfox_api_client.dart';
import 'storage.dart';

/// How many library photos to keep for the offline gallery.
const int kGalleryCacheLimit = 60;

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
    this.userId,
  });

  final PixelfoxApiClient Function() _clientProvider;
  final PrefsStore? _prefs;

  /// Library cache is per account. Album grids are not cached.
  final int? Function()? userId;

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
  Future<void>? _refreshLoop;
  Future<void>? _loadMoreFuture;
  bool _refreshAgain = false;
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
    if (_loaded) return;
    final running = _refreshLoop;
    if (running != null) {
      await running;
      return;
    }
    await refresh();
  }

  Future<void> refresh() {
    _refreshAgain = true;
    final running = _refreshLoop;
    if (running != null) return running;
    final loop = _drainRefreshes();
    _refreshLoop = loop;
    return loop;
  }

  Future<void> _drainRefreshes() async {
    try {
      while (true) {
        if (!_refreshAgain) {
          await Future<void>.value();
          if (!_refreshAgain) return;
        }
        _refreshAgain = false;
        await _loadSavedOrder();
        await _refreshOnce();
      }
    } finally {
      _refreshLoop = null;
    }
  }

  Future<void> _refreshOnce() async {
    final pendingMore = _loadMoreFuture;
    if (pendingMore != null) await pendingMore;
    final epoch = _epoch;
    if (!_loaded) {
      _loading = true;
      notifyListeners();
      await _hydrateCache(epoch);
      if (epoch != _epoch) return;
      // A cached page is already on screen. Leave sort and refresh usable
      // while this attempt is still waiting on the network.
      if (_loaded) {
        _loading = false;
        notifyListeners();
      }
    }
    await _fetchPage(epoch: epoch, append: false);
  }

  Future<void> loadMore() async {
    await _loadSavedOrder();
    if (!_hasMore || _loading || _loadingMore || _refreshLoop != null) return;
    final epoch = _epoch;
    _loadingMore = true;
    notifyListeners();
    final run = _fetchPage(epoch: epoch, append: true);
    _loadMoreFuture = run;
    try {
      await run;
    } finally {
      if (identical(_loadMoreFuture, run)) _loadMoreFuture = null;
    }
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
    await _hydrateCache(epoch);
    if (epoch != _epoch) return;
    notifyListeners();
    await _fetchPage(epoch: epoch, append: false);
  }

  Future<void> _fetchPage({required int epoch, required bool append}) async {
    final client = _clientProvider();
    try {
      final page = await client
          .listImages(
            cursor: append ? _nextCursor : null,
            albumId: albumId,
            sort: _order.requestValue,
          )
          .timeout(
            kReachabilityTimeout,
            onTimeout: () {
              client.close();
              throw TimeoutException('gallery', kReachabilityTimeout);
            },
          );
      if (epoch != _epoch) return;
      _items = append ? [..._items, ...page.items] : page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loaded = true;
      _error = null;
      _snackMessage = null;
      if (!append) await _writeCache();
    } catch (e) {
      if (epoch != _epoch) return;
      if (isTransportFailure(e)) {
        // Keep a cached page. The offline banner explains why it is stale.
        _error = _items.isEmpty ? NetworkErrorCodes.unreachable : null;
        _snackMessage = null;
      } else {
        final message = e is PixelfoxApiException ? e.message : e.toString();
        if (append || _loaded) {
          _snackMessage = message;
        } else {
          _error = message;
        }
      }
    } finally {
      client.close();
    }
    if (epoch != _epoch) return;
    _loading = false;
    _loadingMore = false;
    notifyListeners();
  }

  String? _cacheKey() {
    if (albumId != null || _prefs == null) return null;
    final id = userId?.call();
    if (id == null) return null;
    return AppBrand.current.galleryPageCacheKey(id, _order.name);
  }

  Future<void> _hydrateCache(int epoch) async {
    final key = _cacheKey();
    if (key == null) return;
    final raw = await _prefs!.getString(key);
    if (raw == null || epoch != _epoch) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || epoch != _epoch) return;
      final page = PixelfoxImagePage.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (page.items.isEmpty || epoch != _epoch) return;
      _items = page.items;
      _hasMore = false;
      _nextCursor = null;
      _loaded = true;
      _error = null;
      _snackMessage = null;
    } catch (_) {}
  }

  Future<void> _writeCache() async {
    final key = _cacheKey();
    if (key == null) return;
    if (_items.isEmpty) {
      try {
        await _prefs!.remove(key);
      } catch (_) {}
      return;
    }
    final items = _items
        .take(kGalleryCacheLimit)
        .map((image) => image.toJson())
        .toList();
    try {
      await _prefs!.setString(
        key,
        jsonEncode({'items': items, 'has_more': false}),
      );
    } catch (_) {}
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
