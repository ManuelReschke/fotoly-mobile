/// Image from GET /api/v1/images.
class PixelfoxImage {
  const PixelfoxImage({
    required this.imageUuid,
    required this.stableUrl,
    this.title = '',
    this.fileName = '',
    this.width,
    this.height,
    this.createdAt,
    this.isNsfw = false,
  });

  final String imageUuid;
  final String stableUrl;
  final String title;
  final String fileName;
  final int? width;
  final int? height;
  final DateTime? createdAt;
  final bool isNsfw;

  static PixelfoxImage? tryParse(Map<String, dynamic> json) {
    final uuid = (json['image_uuid'] as String?)?.trim() ?? '';
    final url = (json['stable_url'] as String?)?.trim() ?? '';
    if (uuid.isEmpty || url.isEmpty) return null;
    DateTime? createdAt;
    final rawCreated = json['created_at'] as String?;
    if (rawCreated != null && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }
    return PixelfoxImage(
      imageUuid: uuid,
      stableUrl: url,
      title: json['title'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
      createdAt: createdAt,
      isNsfw: json['is_nsfw'] as bool? ?? false,
    );
  }

  factory PixelfoxImage.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw FormatException('PixelfoxImage missing image_uuid or stable_url');
    }
    return parsed;
  }
}

class PixelfoxImagePage {
  const PixelfoxImagePage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<PixelfoxImage> items;
  final bool hasMore;
  final String? nextCursor;

  factory PixelfoxImagePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    final items = <PixelfoxImage>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final parsed = PixelfoxImage.tryParse(Map<String, dynamic>.from(entry));
      if (parsed != null) items.add(parsed);
    }
    final cursor = json['next_cursor'];
    return PixelfoxImagePage(
      items: items,
      hasMore: json['has_more'] as bool? ?? false,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }
}
