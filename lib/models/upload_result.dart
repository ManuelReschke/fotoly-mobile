/// Response after multipart upload to session upload_url.
class UploadResult {
  const UploadResult({
    required this.imageUuid,
    this.viewUrl,
    this.url,
    this.duplicate = false,
  });

  final String imageUuid;
  final String? viewUrl;
  final String? url;
  final bool duplicate;

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      imageUuid: json['image_uuid'] as String,
      viewUrl: json['view_url'] as String?,
      url: json['url'] as String?,
      duplicate: json['duplicate'] as bool? ?? false,
    );
  }
}
