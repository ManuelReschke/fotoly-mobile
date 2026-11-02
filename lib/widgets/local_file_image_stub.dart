import 'package:flutter/widgets.dart';

/// Web has no local folder scan, so pending tiles stay a placeholder.
Widget localFileImage({
  required String path,
  required int cacheWidth,
  required Widget placeholder,
}) {
  return placeholder;
}
