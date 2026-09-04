import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/backup_status.dart';
import '../models/pixelfox_image.dart';
import 'pixelfox_api_client.dart';

class GalleryService extends ChangeNotifier {
  GalleryService({required this._clientProvider});

  final PixelfoxApiClient Function() _clientProvider;

  List<PixelfoxImage> _items = [];
  bool _hasMore = false;
  String? _nextCursor;
  bool _loaded = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _snackMessage;

  List<PixelfoxImage> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get loaded => _loaded;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  String? get snackMessage => _snackMessage;

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
    if (_loading || _loadingMore) return;
    _loading = true;
    notifyListeners();
    try {
      final page = await _clientProvider().listImages();
      _items = page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
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

  Future<void> loadMore() async {
    if (!_hasMore || _loading || _loadingMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _clientProvider().listImages(cursor: _nextCursor);
      _items = [..._items, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _snackMessage = null;
    } catch (e) {
      _snackMessage = e is PixelfoxApiException ? e.message : e.toString();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void onBackupPhaseChanged(BackupPhase previous, BackupPhase next) {
    if (previous == BackupPhase.working &&
        next == BackupPhase.success &&
        _loaded) {
      unawaited(refresh());
    }
  }
}
