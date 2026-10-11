/// Album from GET/POST/PATCH /api/v1/albums.
class PixelfoxAlbum {
  const PixelfoxAlbum({
    required this.id,
    required this.title,
    this.description = '',
    this.imageCount = 0,
    this.isPublic = false,
    this.isNsfw = false,
    this.shareLink = '',
    this.viewUrl = '',
    this.hasSharePassword = false,
    this.imageSortOrder = sortNewest,
    this.coverImageUuid,
    this.coverStableUrl,
  });

  /// Newest images first. Matches the API value `desc`.
  static const String sortNewest = 'desc';

  /// Oldest images first. Matches the API value `asc`.
  static const String sortOldest = 'asc';

  final int id;
  final String title;
  final String description;
  final int imageCount;
  final bool isPublic;
  final bool isNsfw;
  final String shareLink;
  final String viewUrl;
  final bool hasSharePassword;
  final String imageSortOrder;

  /// UUID of the cover image. Null when the album has no live cover.
  final String? coverImageUuid;

  /// Small stable preview URL of [coverImageUuid]. Null when there is no cover.
  final String? coverStableUrl;

  bool get isOldestFirst => imageSortOrder == sortOldest;

  PixelfoxAlbum copyWith({
    String? title,
    String? description,
    int? imageCount,
    bool? isPublic,
    bool? isNsfw,
    String? shareLink,
    String? viewUrl,
    bool? hasSharePassword,
    String? imageSortOrder,
    String? coverImageUuid,
    String? coverStableUrl,
    bool clearCover = false,
  }) {
    return PixelfoxAlbum(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageCount: imageCount ?? this.imageCount,
      isPublic: isPublic ?? this.isPublic,
      isNsfw: isNsfw ?? this.isNsfw,
      shareLink: shareLink ?? this.shareLink,
      viewUrl: viewUrl ?? this.viewUrl,
      hasSharePassword: hasSharePassword ?? this.hasSharePassword,
      imageSortOrder: imageSortOrder ?? this.imageSortOrder,
      coverImageUuid: clearCover
          ? null
          : (coverImageUuid ?? this.coverImageUuid),
      coverStableUrl: clearCover
          ? null
          : (coverStableUrl ?? this.coverStableUrl),
    );
  }

  factory PixelfoxAlbum.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    if (id == null) {
      throw const FormatException('PixelfoxAlbum missing id');
    }
    final sort = json['image_sort_order'] as String?;
    final cover = _optionalString(json['cover_image_uuid']);
    final coverUrl = _optionalString(json['cover_stable_url']);
    return PixelfoxAlbum(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageCount: _asInt(json['image_count']) ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
      isNsfw: json['is_nsfw'] as bool? ?? false,
      shareLink: json['share_link'] as String? ?? '',
      viewUrl: json['view_url'] as String? ?? '',
      hasSharePassword: json['has_share_password'] as bool? ?? false,
      imageSortOrder: sort == sortOldest ? sortOldest : sortNewest,
      coverImageUuid: cover,
      coverStableUrl: coverUrl,
    );
  }
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

/// Fields sent to POST /albums and PATCH /albums/{id}.
class AlbumInput {
  const AlbumInput({
    required this.title,
    this.description = '',
    this.isPublic = false,
    this.isNsfw = false,
    this.imageSortOrder = PixelfoxAlbum.sortNewest,
    this.sharePassword,
  });

  final String title;
  final String description;
  final bool isPublic;
  final bool isNsfw;
  final String imageSortOrder;

  /// Null leaves an existing share password unchanged.
  /// Empty string clears it.
  final String? sharePassword;

  String get normalizedSort => imageSortOrder == PixelfoxAlbum.sortOldest
      ? PixelfoxAlbum.sortOldest
      : PixelfoxAlbum.sortNewest;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'is_public': isPublic,
    'is_nsfw': isNsfw,
    'image_sort_order': normalizedSort,
    if (sharePassword != null) 'share_password': sharePassword,
  };
}

/// Result of POST /albums/{id}/images.
class AlbumImageAssignResult {
  const AlbumImageAssignResult({
    required this.added,
    required this.alreadyAssigned,
    required this.imageCount,
  });

  final List<String> added;
  final List<String> alreadyAssigned;
  final int imageCount;

  factory AlbumImageAssignResult.fromJson(Map<String, dynamic> json) {
    return AlbumImageAssignResult(
      added: _stringList(json['added']),
      alreadyAssigned: _stringList(json['already_assigned']),
      imageCount: _asInt(json['image_count']) ?? 0,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}
