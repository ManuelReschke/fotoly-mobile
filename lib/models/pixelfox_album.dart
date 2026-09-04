/// Album from GET /api/v1/albums.
class PixelfoxAlbum {
  const PixelfoxAlbum({
    required this.id,
    required this.title,
    this.imageCount = 0,
    this.isPublic = false,
    this.isNsfw = false,
  });

  final int id;
  final String title;
  final int imageCount;
  final bool isPublic;
  final bool isNsfw;

  factory PixelfoxAlbum.fromJson(Map<String, dynamic> json) {
    return PixelfoxAlbum(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      imageCount: json['image_count'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
      isNsfw: json['is_nsfw'] as bool? ?? false,
    );
  }
}
