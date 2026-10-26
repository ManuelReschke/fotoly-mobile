import 'dart:io';

import 'package:flutter/foundation.dart';

/// Stock Android camera roll. Same path the settings field shows as a hint.
const kAndroidCameraFolder = '/storage/emulated/0/DCIM/Camera';

/// Android locations tried in order. The stock camera folder wins when it
/// exists; DCIM is only a fallback for devices that do not use that folder.
const kAndroidCameraFolderCandidates = [
  kAndroidCameraFolder,
  '/sdcard/DCIM/Camera',
  '/storage/emulated/0/DCIM',
  '/sdcard/DCIM',
];

/// Ordered directory candidates for the one-tap camera backup.
List<String> standardCameraFolderCandidates({
  required bool android,
  required bool ios,
  String? home,
}) {
  if (android) return List<String>.of(kAndroidCameraFolderCandidates);
  // iOS backups stay on the document picker. There is no stable camera path.
  if (ios) return const [];
  if (home == null || home.trim().isEmpty) return const [];
  final root = home.trim();
  return ['$root/DCIM/Camera', '$root/Pictures', '$root/Bilder'];
}

/// First [candidates] entry for which [exists] is true.
String? firstExistingDirectory(
  Iterable<String> candidates,
  bool Function(String path) exists,
) {
  final seen = <String>{};
  for (final raw in candidates) {
    final path = raw.trim();
    if (path.isEmpty || !seen.add(path)) continue;
    if (exists(path)) return path;
  }
  return null;
}

/// Resolves the device camera folder, or null when this platform has none.
String? locateStandardCameraFolder({
  bool? isAndroid,
  bool? isIOS,
  String? home,
  bool Function(String path)? exists,
}) {
  if (kIsWeb) return null;
  final android = isAndroid ?? Platform.isAndroid;
  final ios = isIOS ?? Platform.isIOS;
  final resolvedHome = home ?? (android || ios ? null : _desktopHome());
  final candidates = standardCameraFolderCandidates(
    android: android,
    ios: ios,
    home: resolvedHome,
  );
  return firstExistingDirectory(candidates, exists ?? _directoryExists);
}

String? _desktopHome() {
  final home = Platform.environment['HOME'];
  if (home == null || home.trim().isEmpty) return null;
  return home.trim();
}

bool _directoryExists(String path) {
  try {
    return Directory(path).existsSync();
  } catch (_) {
    return false;
  }
}
