import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Image extensions considered for backup.
const kImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.heic',
  '.heif',
  '.bmp',
  '.tif',
  '.tiff',
};

/// Thrown when no images could be listed because selected folders are
/// unreadable (permission denied, missing path, or mixed access with empty
/// readable folders). Map to l10n in the UI — do not show [toString] raw.
class FoldersInaccessibleException implements Exception {
  const FoldersInaccessibleException(this.folders);

  /// Paths that could not be listed.
  final List<String> folders;

  @override
  String toString() => 'FoldersInaccessibleException(${folders.join(', ')})';
}

/// One local image file ready for upload.
class LocalImageFile {
  const LocalImageFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// Enumerates image files under selected folders (injectable for tests).
abstract class FileScanner {
  /// Returns image files found under [folders] (non-recursive depth configurable).
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  });
}

/// Production scanner using dart:io Directory listing.
class IoFileScanner implements FileScanner {
  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) {
    return _scanFoldersOffUi(List<String>.of(folders), recursive);
  }
}

typedef _FolderScan = ({
  List<String> paths,
  List<int> sizes,
  List<String> inaccessible,
});

/// Walks [folders] on a background isolate so a large library does not freeze
/// the UI. Only primitive lists cross the isolate boundary.
Future<List<LocalImageFile>> _scanFoldersOffUi(
  List<String> folders,
  bool recursive,
) async {
  if (folders.isEmpty) return [];
  final scanned = await Isolate.run(
    () => _scanImageFolders(folders, recursive),
  );
  if (scanned.paths.isEmpty && scanned.inaccessible.isNotEmpty) {
    throw FoldersInaccessibleException(List.unmodifiable(scanned.inaccessible));
  }
  return [
    for (var i = 0; i < scanned.paths.length; i++)
      LocalImageFile(
        path: scanned.paths[i],
        name: p.basename(scanned.paths[i]),
        sizeBytes: scanned.sizes[i],
      ),
  ];
}

Future<_FolderScan> _scanImageFolders(
  List<String> folders,
  bool recursive,
) async {
  final found = <(String, int)>[];
  final inaccessible = <String>[];
  final seen = <String>{};

  for (final folder in folders) {
    final dir = Directory(folder);
    try {
      if (!await dir.exists()) {
        inaccessible.add(folder);
        continue;
      }

      final stream = recursive
          ? dir.list(recursive: true, followLinks: false)
          : dir.list();

      await for (final entity in stream) {
        if (entity is! File) continue;
        final path = entity.path;
        final ext = p.extension(path).toLowerCase();
        if (!kImageExtensions.contains(ext)) continue;
        if (!seen.add(path)) continue;
        final stat = await entity.stat();
        found.add((path, stat.size));
      }
    } on FileSystemException {
      // Permission denied or path unreadable — do not abort other folders.
      inaccessible.add(folder);
    }
  }

  found.sort((a, b) => a.$1.compareTo(b.$1));
  return (
    paths: [for (final file in found) file.$1],
    sizes: [for (final file in found) file.$2],
    inaccessible: inaccessible,
  );
}

/// Test double: returns a fixed list filtered by selected folders.
class FakeFileScanner implements FileScanner {
  FakeFileScanner(this.allFiles);

  final List<LocalImageFile> allFiles;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) async {
    final selected = folders.toSet();
    return allFiles.where((f) {
      for (final folder in selected) {
        // Path is under folder if it starts with folder + separator or equals.
        if (f.path == folder ||
            f.path.startsWith(folder.endsWith('/') ? folder : '$folder/')) {
          return true;
        }
      }
      return false;
    }).toList()..sort((a, b) => a.path.compareTo(b.path));
  }
}
