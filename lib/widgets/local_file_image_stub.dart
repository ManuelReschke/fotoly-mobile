import 'package:flutter/widgets.dart';

/// Web has no local folder scan, so pending tiles stay a placeholder.
Widget localFileImage({
  required String path,
  required int cacheWidth,
  required Widget placeholder,
  BoxFit fit = BoxFit.cover,
  FilterQuality filterQuality = FilterQuality.low,
}) {
  return placeholder;
}
