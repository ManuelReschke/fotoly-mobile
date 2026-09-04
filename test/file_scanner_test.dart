import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoly_mobile/services/file_scanner.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('pixelfox_scan_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('IoFileScanner finds images recursively', () async {
    final cam = Directory('${tempRoot.path}/DCIM/Camera')
      ..createSync(recursive: true);
    File('${cam.path}/a.jpg').writeAsBytesSync([1, 2, 3]);
    File('${cam.path}/note.txt').writeAsStringSync('skip');
    File('${tempRoot.path}/DCIM/other.png').writeAsBytesSync([4]);

    final files = await IoFileScanner().scan([tempRoot.path]);
    expect(files.map((f) => f.name).toList()..sort(), ['a.jpg', 'other.png']);
  });

  test('IoFileScanner throws when no selected folder is readable', () async {
    await expectLater(
      () => IoFileScanner().scan(['/definitely/not/a/real/folder/xyz']),
      throwsA(isA<FoldersInaccessibleException>()),
    );
  });

  test(
    'IoFileScanner throws when some folders inaccessible and no images found',
    () async {
      final emptyOk = Directory('${tempRoot.path}/empty')
        ..createSync(recursive: true);
      await expectLater(
        () => IoFileScanner().scan([
          emptyOk.path,
          '/definitely/not/a/real/folder/xyz',
        ]),
        throwsA(
          isA<FoldersInaccessibleException>().having(
            (e) => e.folders,
            'folders',
            contains('/definitely/not/a/real/folder/xyz'),
          ),
        ),
      );
    },
  );

  test(
    'IoFileScanner returns images when at least one folder is readable',
    () async {
      final cam = Directory('${tempRoot.path}/ok')..createSync(recursive: true);
      File('${cam.path}/a.jpg').writeAsBytesSync([1]);
      final files = await IoFileScanner().scan([
        cam.path,
        '/definitely/not/a/real/folder/xyz',
      ]);
      expect(files.map((f) => f.name), ['a.jpg']);
    },
  );
}
