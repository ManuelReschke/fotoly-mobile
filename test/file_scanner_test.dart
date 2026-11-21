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

  test(
    'incremental scans reuse unchanged nested folders and find new ones',
    () async {
      final first = Directory('${tempRoot.path}/first')..createSync();
      final second = Directory('${tempRoot.path}/second')..createSync();
      final untouched = File('${first.path}/untouched.jpg')
        ..writeAsBytesSync([1]);
      final removed = File('${second.path}/removed.jpg')..writeAsBytesSync([2]);
      final scanner = IoFileScanner();

      final original = await scanner.scan([tempRoot.path]);
      final unchanged = await scanner.scanIncrementally([tempRoot.path]);
      expect(unchanged, same(original));

      await removed.delete();
      final added = await Directory('${second.path}/new').create();
      await File('${added.path}/added.jpg').writeAsBytes([3, 4]);

      final updated = await scanner.scanIncrementally([tempRoot.path]);
      expect(updated.map((file) => file.name), ['untouched.jpg', 'added.jpg']);
      expect(updated.first.path, untouched.path);
      expect(updated.last.sizeBytes, 2);
    },
  );

  test('a missing selected folder is retried when it reappears', () async {
    final folder = Directory('${tempRoot.path}/restored')..createSync();
    final scanner = IoFileScanner();
    final selection = [folder.path];
    await scanner.scan(selection);
    await folder.delete();
    await expectLater(
      scanner.scanIncrementally(selection),
      throwsA(isA<FoldersInaccessibleException>()),
    );

    await folder.create();
    await File('${folder.path}/photo.jpg').writeAsBytes([1]);
    expect(
      (await scanner.scanIncrementally(selection)).single.name,
      'photo.jpg',
    );
  });

  test('manual and periodic full scans detect in-place file edits', () async {
    final file = File('${tempRoot.path}/photo.jpg')..writeAsBytesSync([1]);
    final manual = IoFileScanner();
    final periodic = IoFileScanner(fullScanInterval: Duration.zero);
    final folders = [tempRoot.path];
    await manual.scan(folders);
    await periodic.scan(folders);

    await file.writeAsBytes([1, 2]);

    expect((await manual.scan(folders)).single.sizeBytes, 2);
    expect((await periodic.scanIncrementally(folders)).single.sizeBytes, 2);
  });
}
