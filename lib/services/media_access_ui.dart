import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'media_access.dart';

/// Ensures media read access and shows a localized snack if denied.
///
/// Returns `true` when the app may read folders (including desktop/web).
Future<bool> ensureMediaAccessOrSnack(
  BuildContext context, {
  required AppStrings strings,
  MediaAccess? mediaAccess,
}) async {
  final access = mediaAccess ?? MediaAccess();
  final result = await access.ensureReadAccess();
  if (!context.mounted) return false;

  switch (result) {
    case MediaAccessResult.granted:
    case MediaAccessResult.notRequired:
      return true;
    case MediaAccessResult.denied:
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.mediaPermissionDenied)));
      return false;
    case MediaAccessResult.permanentlyDenied:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.mediaPermissionPermanentlyDenied),
          action: SnackBarAction(
            label: strings.openSystemSettings,
            onPressed: () {
              access.openSystemSettings();
            },
          ),
        ),
      );
      return false;
  }
}
