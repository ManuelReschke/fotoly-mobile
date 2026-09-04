import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Gravatar helpers — same idea as pixelfox.cc (avatar from account email).
///
/// Hash rules match https://docs.gravatar.com/general/hash/ :
/// trim → lower-case → SHA-256.
class Gravatar {
  Gravatar._();

  /// Normalized email hash used in avatar URLs.
  static String hashEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// HTTPS avatar URL for [email].
  ///
  /// [size] is the requested square edge in CSS pixels (1–2048).
  /// [defaultImage] is a Gravatar `d=` keyword (`mp`, `identicon`, …)
  /// or a URL-encoded custom image URL.
  static String imageUrl(
    String email, {
    int size = 128,
    String defaultImage = 'mp',
  }) {
    final hash = hashEmail(email);
    final s = size.clamp(1, 2048);
    return 'https://www.gravatar.com/avatar/$hash'
        '?s=$s&d=${Uri.encodeQueryComponent(defaultImage)}&r=g';
  }
}
