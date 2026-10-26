import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/services/camera_folder.dart';

void main() {
  test('android prefers the stock camera folder over DCIM', () {
    final found = locateStandardCameraFolder(
      isAndroid: true,
      isIOS: false,
      exists: (path) =>
          path == kAndroidCameraFolder || path == '/storage/emulated/0/DCIM',
    );

    expect(found, kAndroidCameraFolder);
  });

  test('android falls back to DCIM when Camera is missing', () {
    final found = locateStandardCameraFolder(
      isAndroid: true,
      isIOS: false,
      exists: (path) => path == '/storage/emulated/0/DCIM',
    );

    expect(found, '/storage/emulated/0/DCIM');
  });

  test('desktop uses Pictures when the camera folder is missing', () {
    final found = locateStandardCameraFolder(
      isAndroid: false,
      isIOS: false,
      home: '/home/dev',
      exists: (path) => path == '/home/dev/Pictures',
    );

    expect(found, '/home/dev/Pictures');
  });

  test('returns null when no camera folder exists', () {
    expect(
      locateStandardCameraFolder(
        isAndroid: true,
        isIOS: false,
        exists: (_) => false,
      ),
      isNull,
    );
  });

  test('iOS has no standard camera path', () {
    expect(
      locateStandardCameraFolder(
        isAndroid: false,
        isIOS: true,
        home: '/var/mobile',
        exists: (_) => true,
      ),
      isNull,
    );
  });
}
