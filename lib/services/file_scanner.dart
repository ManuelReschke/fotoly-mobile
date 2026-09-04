import 'dart:io';

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
  }) async {
    final results = <LocalImageFile>[];
    final seen = <String>{};

    final inaccessible = <String>[];

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
          results.add(
            LocalImageFile(
              path: path,
              name: p.basename(path),
              sizeBytes: stat.size,
            ),
          );
        }
      } on FileSystemException {
        // Permission denied or path unreadable — do not abort other folders.
        inaccessible.add(folder);
      }
    }

    // Empty inventory + any inaccessible folder looks like "no photos" if we
    // stay silent — surface a typed error for the UI to localize.
    // Partial success (some images found) still returns results.
    if (results.isEmpty && folders.isNotEmpty && inaccessible.isNotEmpty) {
      throw FoldersInaccessibleException(List.unmodifiable(inaccessible));
    }

    results.sort((a, b) => a.path.compareTo(b.path));
    return results;
  }
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
