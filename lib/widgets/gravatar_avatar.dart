import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/gravatar.dart';
import 'pixelfox_logo.dart';

/// Circular avatar loaded from Gravatar for [email], with logo fallback.
class GravatarAvatar extends StatelessWidget {
  const GravatarAvatar({
    super.key,
    required this.email,
    this.size = 52,
    this.borderColor,
    this.backgroundColor,
  });

  final String email;
  final double size;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pixelSize = (size * dpr).round().clamp(40, 512);
    final border = borderColor ?? Colors.white.withValues(alpha: 0.18);
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.12);

    Widget fallback({double logoSize = 28}) => ColoredBox(
      color: bg,
      child: Center(child: PixelfoxLogo(size: logoSize)),
    );

    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return _circle(
        border: border,
        child: fallback(logoSize: size * 0.55),
      );
    }

    final url = Gravatar.imageUrl(trimmed, size: pixelSize);

    return _circle(
      border: border,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            fallback(logoSize: size * 0.55),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: bg,
            child: Center(
              child: SizedBox(
                width: size * 0.35,
                height: size * 0.35,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.foxOrange.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _circle({required Color border, required Widget child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
