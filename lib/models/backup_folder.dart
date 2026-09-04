/// A local folder selected for backup, optionally mapped to a Pixelfox album.
class BackupFolder {
  const BackupFolder({required this.path, this.albumId, this.albumTitle});

  final String path;

  /// Target album on Pixelfox; null = no album (root library).
  final int? albumId;

  /// Cached title for UI (may be stale if renamed on the server).
  final String? albumTitle;

  bool get hasAlbum => albumId != null;

  BackupFolder copyWith({
    String? path,
    int? albumId,
    String? albumTitle,
    bool clearAlbum = false,
  }) {
    return BackupFolder(
      path: path ?? this.path,
      albumId: clearAlbum ? null : (albumId ?? this.albumId),
      albumTitle: clearAlbum ? null : (albumTitle ?? this.albumTitle),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    if (albumId != null) 'album_id': albumId,
    if (albumTitle != null && albumTitle!.isNotEmpty) 'album_title': albumTitle,
  };

  factory BackupFolder.fromJson(Map<String, dynamic> json) {
    return BackupFolder(
      path: json['path'] as String,
      albumId: json['album_id'] as int?,
      albumTitle: json['album_title'] as String?,
    );
  }

  /// Resolve which configured folder “owns” [filePath] (longest path wins).
  static BackupFolder? matchingFolder(
    String filePath,
    List<BackupFolder> folders,
  ) {
    BackupFolder? best;
    for (final folder in folders) {
      final root = folder.path.endsWith('/')
          ? folder.path.substring(0, folder.path.length - 1)
          : folder.path;
      final under = filePath == root || filePath.startsWith('$root/');
      if (!under) continue;
      if (best == null || root.length > best.path.length) {
        best = folder;
      }
    }
    return best;
  }
}
