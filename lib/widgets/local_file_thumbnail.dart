import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'local_file_image_stub.dart'
    if (dart.library.io) 'local_file_image_io.dart';

/// Square preview of one photo still waiting for backup.
class LocalFileThumbnail extends StatelessWidget {
  const LocalFileThumbnail({
    super.key,
    required this.path,
    required this.cacheWidth,
  });

  final String path;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return localFileImage(
      path: path,
      cacheWidth: cacheWidth,
      placeholder: const LocalFileThumbnailPlaceholder(),
    );
  }
}

class LocalFileThumbnailPlaceholder extends StatelessWidget {
  const LocalFileThumbnailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        child: Center(
          child: Icon(Icons.image_outlined, color: AppTheme.foxAmber, size: 28),
        ),
      ),
    );
  }
}
