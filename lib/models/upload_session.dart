/// Response from POST /upload/sessions.
class UploadSession {
  const UploadSession({
    required this.uploadUrl,
    required this.token,
    required this.maxBytes,
    this.expiresAt,
    this.poolId,
    this.albumId,
  });

  final String uploadUrl;
  final String token;
  final int maxBytes;
  final int? expiresAt;
  final int? poolId;
  final int? albumId;

  factory UploadSession.fromJson(Map<String, dynamic> json) {
    return UploadSession(
      uploadUrl: json['upload_url'] as String,
      token: json['token'] as String,
      maxBytes: json['max_bytes'] as int? ?? 0,
      expiresAt: json['expires_at'] as int?,
      poolId: json['pool_id'] as int?,
      albumId: json['album_id'] as int?,
    );
  }
}
