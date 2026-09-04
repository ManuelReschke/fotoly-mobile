import 'package:flutter/material.dart';

import '../config/app_brand.dart';
import '../theme/app_theme.dart';

/// Official PixelFox logo from pixelfox.cc (`/img/pixelfox-logo-*.png`).
class PixelfoxLogo extends StatelessWidget {
  const PixelfoxLogo({super.key, this.size = 72, this.mark = false});

  /// Rendered square size (logo is ~128×123).
  final double size;

  /// Prefer the 32×32 mark (navbar-style) for small placements.
  final bool mark;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mark ? AppTheme.logoMarkAsset : AppTheme.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: '${AppBrand.current.displayName} Logo',
      errorBuilder: (context, error, stackTrace) => Icon(
        AppBrand.current.markIcon,
        size: size * 0.85,
        color: AppTheme.foxOrange,
      ),
    );
  }
}

/// Compact title row: mark + “Pixelfox” label (like the site navbar).
class PixelfoxBrandTitle extends StatelessWidget {
  const PixelfoxBrandTitle({
    super.key,
    this.label,
    this.color = Colors.white,
    this.markSize = 28,
  });

  final String? label;
  final Color color;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelfoxLogo(size: markSize, mark: true),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label ?? AppBrand.current.displayName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
