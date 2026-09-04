import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of ensuring photo/folder read access on mobile.
enum MediaAccessResult {
  /// Permission granted (or limited photo library access on iOS/Android 14+).
  granted,

  /// User denied this time; can ask again later.
  denied,

  /// User chose “don’t ask again” / must enable in system settings.
  permanentlyDenied,

  /// Desktop / web / iOS path-based folders — no runtime media permission needed.
  notRequired,
}

/// Android 13 (Tiramisu) introduced granular media permissions.
const int kAndroidApi33 = 33;

/// Requests runtime storage/photos permission needed to scan backup folders.
///
/// **Android:** declares `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` in the
/// manifest, but both still need a **runtime** grant. Without that,
/// `Directory.list` on paths like `/storage/emulated/0/DCIM` fails.
/// - API 33+: [Permission.photos] only
/// - API ≤32: [Permission.storage] only
///
/// **iOS:** folder backups use the document picker security scope, not the
/// Photos library API. [Permission.photos] does not authorize arbitrary
/// path-based `Directory.list`, so iOS is [MediaAccessResult.notRequired]
/// for this app’s scan model.
///
/// Injectable for tests via [requestPhotos] / [requestStorage] / platform flags
/// and [androidSdkInt].
class MediaAccess {
  MediaAccess({
    Future<PermissionStatus> Function()? requestPhotos,
    Future<PermissionStatus> Function()? requestStorage,
    Future<bool> Function()? openSettings,
    bool? isAndroid,
    bool? isIOS,
    this.androidSdkInt,
  }) : _requestPhotos = requestPhotos ?? (() => Permission.photos.request()),
       _requestStorage = requestStorage ?? (() => Permission.storage.request()),
       _openSettings = openSettings ?? openAppSettings,
       _isAndroid = isAndroid ?? (!kIsWeb && Platform.isAndroid),
       _isIOS = isIOS ?? (!kIsWeb && Platform.isIOS);

  final Future<PermissionStatus> Function() _requestPhotos;
  final Future<PermissionStatus> Function() _requestStorage;
  final Future<bool> Function() _openSettings;
  final bool _isAndroid;
  final bool _isIOS;

  /// Injected Android API level for tests / precise branching. When null,
  /// [ensureReadAccess] tries photos first then storage.
  final int? androidSdkInt;

  /// True when the platform needs a runtime photos/storage grant for path scans.
  ///
  /// iOS is excluded: security-scoped folder access comes from the picker, not
  /// the Photos permission dialog.
  static bool get isRuntimePermissionRequired {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  bool get requiresRuntimePermission => _isAndroid;

  /// Ensure we can read image folders. Safe to call repeatedly.
  Future<MediaAccessResult> ensureReadAccess() async {
    if (_isIOS) {
      // Path-based IoFileScanner relies on document-picker scopes, not PHPhotoLibrary.
      return MediaAccessResult.notRequired;
    }
    if (!_isAndroid) {
      return MediaAccessResult.notRequired;
    }

    final sdk = androidSdkInt;
    if (sdk != null && sdk >= kAndroidApi33) {
      return _fromPhotosStatus(await _requestPhotos());
    }
    if (sdk != null && sdk < kAndroidApi33) {
      return _fromStorageStatus(await _requestStorage());
    }

    // SDK unknown (e.g. default production construct without injection):
    // try photos first (API 33+), then storage only if photos was not permanent.
    final photos = await _requestPhotos();
    if (photos.isGranted || photos.isLimited) {
      return MediaAccessResult.granted;
    }
    if (photos.isPermanentlyDenied) {
      // On API 33+ storage will not help; on older APIs permanent photos deny
      // usually means the user must open settings anyway.
      return MediaAccessResult.permanentlyDenied;
    }

    final storage = await _requestStorage();
    if (storage.isGranted) {
      return MediaAccessResult.granted;
    }
    if (storage.isPermanentlyDenied) {
      return MediaAccessResult.permanentlyDenied;
    }
    return MediaAccessResult.denied;
  }

  MediaAccessResult _fromPhotosStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return MediaAccessResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return MediaAccessResult.permanentlyDenied;
    }
    return MediaAccessResult.denied;
  }

  MediaAccessResult _fromStorageStatus(PermissionStatus status) {
    if (status.isGranted) {
      return MediaAccessResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return MediaAccessResult.permanentlyDenied;
    }
    return MediaAccessResult.denied;
  }

  Future<bool> openSystemSettings() => _openSettings();
}
