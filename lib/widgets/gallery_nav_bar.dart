import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';

class GalleryNavBar extends StatelessWidget {
  const GalleryNavBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.cloud_upload_outlined),
          label: s.navBackup,
        ),
        NavigationDestination(
          icon: const Icon(Icons.photo_library_outlined),
          label: s.navGallery,
        ),
      ],
    );
  }
}
