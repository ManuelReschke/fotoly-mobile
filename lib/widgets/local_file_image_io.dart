import 'dart:io';

import 'package:flutter/widgets.dart';

/// Decodes a local backup photo down to [cacheWidth] pixels.
///
/// Missing or unreadable files show [placeholder] instead of throwing.
Widget localFileImage({
  required String path,
  required int cacheWidth,
  required Widget placeholder,
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.low,
}) {
  final file = File(path);
  try {
    if (!file.existsSync()) return placeholder;
  } catch (_) {
    return placeholder;
  }
  return Image.file(
    file,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    cacheWidth: cacheWidth,
    filterQuality: filterQuality,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) return child;
      return placeholder;
    },
    errorBuilder: (context, error, stackTrace) => placeholder,
  );
}
