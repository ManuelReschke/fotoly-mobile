import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixelfox_mobile/services/media_access.dart';

void main() {
  test('desktop/web path is not required', () async {
    final access = MediaAccess(isAndroid: false, isIOS: false);
    expect(await access.ensureReadAccess(), MediaAccessResult.notRequired);
  });

  test('iOS path-based scans do not require Photos permission', () async {
    var photosRequested = false;
    final access = MediaAccess(
      isAndroid: false,
      isIOS: true,
      requestPhotos: () async {
        photosRequested = true;
        return PermissionStatus.denied;
      },
    );
    expect(await access.ensureReadAccess(), MediaAccessResult.notRequired);
    expect(photosRequested, isFalse);
  });

  test('Android API 33+ uses photos only', () async {
    var storageRequested = false;
    final access = MediaAccess(
      isAndroid: true,
      isIOS: false,
      androidSdkInt: 33,
      requestPhotos: () async => PermissionStatus.granted,
      requestStorage: () async {
        storageRequested = true;
        return PermissionStatus.granted;
      },
    );
    expect(await access.ensureReadAccess(), MediaAccessResult.granted);
    expect(storageRequested, isFalse);
  });

  test('Android API ≤32 uses storage only', () async {
    var photosRequested = false;
    final access = MediaAccess(
      isAndroid: true,
      isIOS: false,
      androidSdkInt: 32,
      requestPhotos: () async {
        photosRequested = true;
        return PermissionStatus.granted;
      },
      requestStorage: () async => PermissionStatus.granted,
    );
    expect(await access.ensureReadAccess(), MediaAccessResult.granted);
    expect(photosRequested, isFalse);
  });

  test('Android API 33+ reports permanently denied from photos', () async {
    final access = MediaAccess(
      isAndroid: true,
      isIOS: false,
      androidSdkInt: 34,
      requestPhotos: () async => PermissionStatus.permanentlyDenied,
      requestStorage: () async => PermissionStatus.granted,
    );
    expect(
      await access.ensureReadAccess(),
      MediaAccessResult.permanentlyDenied,
    );
  });

  test('Android unknown SDK grants when photos allowed', () async {
    final access = MediaAccess(
      isAndroid: true,
      isIOS: false,
      requestPhotos: () async => PermissionStatus.granted,
      requestStorage: () async => PermissionStatus.denied,
    );
    expect(await access.ensureReadAccess(), MediaAccessResult.granted);
  });

  test(
    'Android unknown SDK falls back to storage when photos denied',
    () async {
      final access = MediaAccess(
        isAndroid: true,
        isIOS: false,
        requestPhotos: () async => PermissionStatus.denied,
        requestStorage: () async => PermissionStatus.granted,
      );
      expect(await access.ensureReadAccess(), MediaAccessResult.granted);
    },
  );

  test('Android unknown SDK permanent photos skips storage fallback', () async {
    var storageRequested = false;
    final access = MediaAccess(
      isAndroid: true,
      isIOS: false,
      requestPhotos: () async => PermissionStatus.permanentlyDenied,
      requestStorage: () async {
        storageRequested = true;
        return PermissionStatus.granted;
      },
    );
    expect(
      await access.ensureReadAccess(),
      MediaAccessResult.permanentlyDenied,
    );
    expect(storageRequested, isFalse);
  });
}
