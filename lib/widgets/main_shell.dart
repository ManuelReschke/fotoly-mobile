import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/backup_status.dart';
import '../screens/gallery_screen.dart';
import '../screens/home_screen.dart';
import '../services/backup_service.dart';
import '../services/gallery_service.dart';
import 'gallery_nav_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _galleryVisited = false;
  BackupPhase _lastPhase = BackupPhase.idle;
  BackupService? _backup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final backup = context.read<BackupService>();
    if (identical(_backup, backup)) return;
    _backup?.removeListener(_onBackup);
    _backup = backup;
    _lastPhase = backup.status.phase;
    backup.addListener(_onBackup);
  }

  void _onBackup() {
    if (!mounted) return;
    final backup = context.read<BackupService>();
    final gallery = context.read<GalleryService>();
    final next = backup.status.phase;
    if (next != _lastPhase) {
      gallery.onBackupPhaseChanged(_lastPhase, next);
      _lastPhase = next;
    }
  }

  @override
  void dispose() {
    _backup?.removeListener(_onBackup);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          // GalleryScreen.initState calls ensureLoaded; keep it unmounted
          // until the first Gallery tab visit so login does not GET /images.
          _galleryVisited ? const GalleryScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: GalleryNavBar(
        index: _index,
        onChanged: (value) {
          setState(() {
            _index = value;
            if (value == 1) _galleryVisited = true;
          });
        },
      ),
    );
  }
}
