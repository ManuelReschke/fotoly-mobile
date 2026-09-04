/// Authenticated user profile from GET /user/profile.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.status,
    required this.plan,
    this.maxUploadBytes,
    this.storageQuotaBytes,
    this.storageUsedBytes,
    this.storageRemainingBytes,
    this.imageCount,
  });

  final int id;
  final String username;
  final String email;
  final String status;
  final String plan;
  final int? maxUploadBytes;
  final int? storageQuotaBytes;
  final int? storageUsedBytes;
  final int? storageRemainingBytes;
  final int? imageCount;

  /// 0.0–1.0 of quota used; null if quota unknown.
  double? get storageUsageRatio {
    final quota = storageQuotaBytes;
    final used = storageUsedBytes;
    if (quota == null || quota <= 0 || used == null) return null;
    return (used / quota).clamp(0.0, 1.0);
  }

  /// True when usage data is complete enough to draw the bar.
  bool get hasStorageUsage =>
      storageQuotaBytes != null &&
      storageQuotaBytes! > 0 &&
      storageUsedBytes != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final limits = json['limits'] as Map<String, dynamic>?;
    final stats = json['stats'] as Map<String, dynamic>?;
    final images = stats?['images'] as Map<String, dynamic>?;

    final used = images?['storage_used_bytes'] as int?;
    final remaining = images?['storage_remaining_bytes'] as int?;
    final quota = limits?['storage_quota_bytes'] as int?;

    // Prefer API remaining; else derive from quota − used.
    final resolvedRemaining =
        remaining ??
        (quota != null && used != null ? (quota - used).clamp(0, quota) : null);

    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? '',
      plan: json['plan'] as String? ?? '',
      maxUploadBytes: limits?['max_upload_bytes'] as int?,
      storageQuotaBytes: quota,
      storageUsedBytes: used,
      storageRemainingBytes: resolvedRemaining,
      imageCount: images?['count'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'status': status,
    'plan': plan,
    'storage_used_bytes': storageUsedBytes,
    'storage_quota_bytes': storageQuotaBytes,
  };
}

/// Human-readable byte sizes (e.g. 700 MB, 1.2 GB).
String formatBytes(int bytes, {int fractionDigits = 1}) {
  if (bytes < 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '${value.round()} ${units[unit]}';
  final digits = value >= 100 ? 0 : fractionDigits;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
