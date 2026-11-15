import 'dart:convert';

/// Active member from GET/POST /api/v1/albums/{id}/members.
class AlbumMember {
  const AlbumMember({
    required this.userId,
    required this.username,
    this.role = roleViewer,
    this.origin = originInvite,
    this.createdAt,
  });

  static const String roleViewer = 'viewer';
  static const String originInvite = 'invite';
  static const String originLinkSave = 'link_save';

  final int userId;
  final String username;
  final String role;
  final String origin;
  final DateTime? createdAt;

  bool get savedFromLink => origin == originLinkSave;

  factory AlbumMember.fromJson(Map<String, dynamic> json) {
    final userId = _asInt(json['user_id']);
    if (userId == null || userId <= 0) {
      throw const FormatException('AlbumMember missing user_id');
    }
    return AlbumMember(
      userId: userId,
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? roleViewer,
      origin: json['origin'] as String? ?? originInvite,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

/// Result of inviting a member. [alreadyMember] is true on HTTP 200.
class AlbumMemberInvite {
  const AlbumMemberInvite({required this.member, required this.alreadyMember});

  final AlbumMember member;
  final bool alreadyMember;

  factory AlbumMemberInvite.fromJson(Map<String, dynamic> json) {
    return AlbumMemberInvite(
      member: AlbumMember.fromJson(json),
      alreadyMember: json['already_member'] as bool? ?? false,
    );
  }
}

/// One account when a username matches more than one active user.
class AlbumMemberCandidate {
  const AlbumMemberCandidate({required this.userId, required this.username});

  final int userId;
  final String username;

  static AlbumMemberCandidate? tryFromJson(Map<String, dynamic> json) {
    final userId = _asInt(json['user_id']);
    if (userId == null || userId <= 0) return null;
    return AlbumMemberCandidate(
      userId: userId,
      username: json['username'] as String? ?? '',
    );
  }
}

/// Candidates from a 409 invite response. Empty when the body has none.
List<AlbumMemberCandidate> albumMemberCandidatesFromBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final raw = decoded['candidates'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (entry) => AlbumMemberCandidate.tryFromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .whereType<AlbumMemberCandidate>()
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Splits the members field into one username or one complete email address.
///
/// A value that contains @ is an email. Anything else stays a display name.
class AlbumInviteQuery {
  const AlbumInviteQuery._({this.username, this.email, this.issue});

  static const String required = 'required';
  static const String usernameTooLong = 'username_too_long';
  static const String emailTooLong = 'email_too_long';
  static const String incompleteEmail = 'incomplete_email';

  final String? username;
  final String? email;

  /// [required], [usernameTooLong], [emailTooLong], or [incompleteEmail].
  final String? issue;

  factory AlbumInviteQuery.parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const AlbumInviteQuery._(issue: required);
    }
    if (value.contains('@')) {
      if (value.runes.length > 200) {
        return const AlbumInviteQuery._(issue: emailTooLong);
      }
      if (!_completeEmail(value)) {
        return const AlbumInviteQuery._(issue: incompleteEmail);
      }
      return AlbumInviteQuery._(email: value);
    }
    if (value.runes.length > 150) {
      return const AlbumInviteQuery._(issue: usernameTooLong);
    }
    return AlbumInviteQuery._(username: value);
  }
}

bool _completeEmail(String value) {
  final at = value.indexOf('@');
  if (at <= 0 || at == value.length - 1 || at != value.lastIndexOf('@')) {
    return false;
  }
  final local = value.substring(0, at);
  final domain = value.substring(at + 1);
  if (local.contains(RegExp(r'[ \t]')) || domain.contains(RegExp(r'[ \t]'))) {
    return false;
  }
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.');
}

/// Category from GET/POST /api/v1/album-categories.
class AlbumCategory {
  const AlbumCategory({
    required this.id,
    required this.name,
    this.slug = '',
    this.scope = scopePrivate,
    this.albumCount = 0,
  });

  static const String scopePrivate = 'private';
  static const String scopePublic = 'public';

  /// Matches the API cap on one assignment request.
  static const int maxPerAlbum = 100;

  final int id;
  final String name;
  final String slug;
  final String scope;
  final int albumCount;

  bool get isPublic => scope == scopePublic;

  static AlbumCategory? tryFromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    if (id == null || id <= 0) return null;
    final scope = json['scope'] as String? ?? scopePrivate;
    return AlbumCategory(
      id: id,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      scope: scope == scopePublic ? scopePublic : scopePrivate,
      albumCount: _asInt(json['album_count']) ?? 0,
    );
  }
}

/// Why [raw] cannot be created as a private category, or null when it is valid.
///
/// The API allows letters, digits, and hyphens, at most 120 characters.
String? albumCategoryNameIssue(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return 'required';
  if (name.length > 120) return 'too_long';
  if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(name)) return 'charset';
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
