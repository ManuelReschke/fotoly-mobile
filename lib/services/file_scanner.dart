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
  IoFileScanner({this.fullScanInterval = const Duration(minutes: 5)});

  /// Directory metadata may stay unchanged when an existing file is edited.
  final Duration fullScanInterval;
  final Stopwatch _sinceFullScan = Stopwatch();
  ({String paths, bool recursive})? _selection;
  Map<String, _DirectoryIndex> _directories = {};
  Map<String, List<LocalImageFile>> _imagesByDirectory = {};
  List<LocalImageFile> _images = const [];
  int _generation = 0;

  @override
  Future<List<LocalImageFile>> scan(
    List<String> folders, {
    bool recursive = true,
  }) => _scan(folders, recursive: recursive, incremental: false);

  /// Polls known directories, listing files only where metadata changed.
  /// Returns the same list instance when the cached inventory can be reused.
  Future<List<LocalImageFile>> scanIncrementally(List<String> folders) =>
      _scan(folders, recursive: true, incremental: true);

  Future<List<LocalImageFile>> _scan(
    List<String> folders, {
    required bool recursive,
    required bool incremental,
  }) async {
    final generation = ++_generation;
    if (folders.isEmpty) {
      _selection = null;
      _directories = {};
      _imagesByDirectory = {};
      return _images = const [];
    }

    final selection = (paths: folders.join('\u0000'), recursive: recursive);
    final reuse =
        incremental &&
        _selection == selection &&
        _sinceFullScan.elapsed < fullScanInterval;
    final previousDirectories = reuse
        ? _directories
        : <String, _DirectoryIndex>{};
    final previousImages = reuse
        ? _imagesByDirectory
        : <String, List<LocalImageFile>>{};
    final previousResult = _images;
    final scan = await _scanOffUi(
      List<String>.of(folders),
      recursive,
      previousDirectories,
    );
    final unchanged =
        reuse &&
        scan.listedImages.isEmpty &&
        scan.directories.length == previousDirectories.length;
    final imagesByDirectory = unchanged
        ? previousImages
        : {
            for (final path in scan.directories.keys)
              path: scan.listedImages[path] ?? previousImages[path]!,
          };
    final images = unchanged
        ? previousResult
        : scan.fullImages ??
              await _flattenOffUi(imagesByDirectory.values.toList());

    if (generation == _generation) {
      _selection = selection;
      _directories = scan.directories;
      _imagesByDirectory = imagesByDirectory;
      _images = images;
      if (!reuse) {
        _sinceFullScan
          ..reset()
          ..start();
      }
    }
    if (images.isEmpty && scan.inaccessible.isNotEmpty) {
      throw FoldersInaccessibleException(List.unmodifiable(scan.inaccessible));
    }
    return images;
  }
}

typedef _DirectoryIndex = ({
  DateTime modified,
  DateTime changed,
  List<String> children,
});

typedef _FolderScan = ({
  Map<String, _DirectoryIndex> directories,
  Map<String, List<LocalImageFile>> listedImages,
  List<LocalImageFile>? fullImages,
  List<String> inaccessible,
});

// An unchanged poll sends only directory metadata through the isolate.
Future<_FolderScan> _scanOffUi(
  List<String> folders,
  bool recursive,
  Map<String, _DirectoryIndex> previous,
) => Isolate.run(() => _scanImageFolders(folders, recursive, previous));

Future<List<LocalImageFile>> _flattenOffUi(
  List<List<LocalImageFile>> directories,
) => Isolate.run(() => _flattenImages(directories));

List<LocalImageFile> _flattenImages(
  Iterable<List<LocalImageFile>> imagesByDirectory,
) {
  final seen = <String>{};
  final images = [
    for (final directory in imagesByDirectory)
      for (final image in directory)
        if (seen.add(image.path)) image,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return List.unmodifiable(images);
}

Future<_FolderScan> _scanImageFolders(
  List<String> folders,
  bool recursive,
  Map<String, _DirectoryIndex> previous,
) async {
  final directories = <String, _DirectoryIndex>{};
  final listedImages = <String, List<LocalImageFile>>{};
  final inaccessible = <String>{};

  for (final folder in folders) {
    final pending = [folder];
    while (pending.isNotEmpty) {
      final path = pending.removeLast();
      if (directories.containsKey(path)) continue;
      try {
        // A previously scanned child can be replaced by a symlink.
        if (path != folder &&
            await FileSystemEntity.type(path, followLinks: false) !=
                FileSystemEntityType.directory) {
          continue;
        }
        final dir = Directory(path);
        final stat = await dir.stat();
        if (stat.type != FileSystemEntityType.directory) {
          if (path == folder) inaccessible.add(folder);
          continue;
        }
        final cached = previous[path];
        if (cached != null &&
            cached.modified == stat.modified &&
            cached.changed == stat.changed) {
          directories[path] = cached;
          pending.addAll(cached.children);
          continue;
        }

        final children = <String>[];
        final images = <LocalImageFile>[];
        await for (final entity in dir.list(followLinks: !recursive)) {
          if (recursive && entity is Directory) {
            children.add(entity.path);
          } else if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (!kImageExtensions.contains(ext)) continue;
            final fileStat = await entity.stat();
            if (fileStat.type != FileSystemEntityType.file) continue;
            images.add(
              LocalImageFile(
                path: entity.path,
                name: p.basename(entity.path),
                sizeBytes: fileStat.size,
              ),
            );
          }
        }
        directories[path] = (
          modified: stat.modified,
          changed: stat.changed,
          children: children,
        );
        listedImages[path] = images;
        pending.addAll(children);
      } on FileSystemException {
        inaccessible.add(folder);
      }
    }
  }

  return (
    directories: directories,
    listedImages: listedImages,
    fullImages: listedImages.length == directories.length
        ? _flattenImages(listedImages.values)
        : null,
    inaccessible: inaccessible.toList(),
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
