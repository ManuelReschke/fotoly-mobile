import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const String kGalleryCacheKey = 'pixelfoxGallery';

typedef GalleryImageBuilder =
    Widget Function({
      required String url,
      required BoxFit fit,
      int? memCacheWidth,
      int? memCacheHeight,
    });

CacheManager? _galleryCache;

CacheManager galleryCacheManager() {
  return _galleryCache ??= CacheManager(
    Config(
      kGalleryCacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
    ),
  );
}

class GalleryImage extends StatelessWidget {
  const GalleryImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.errorLabel,
    this.cacheManager,
  });

  final String url;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final String? errorLabel;
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      cacheManager: cacheManager ?? galleryCacheManager(),
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) => ColoredBox(color: scheme.surfaceContainerHighest),
      errorWidget: (context, url, error) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
            if (errorLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorLabel!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
