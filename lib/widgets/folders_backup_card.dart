import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../l10n/l10n_scope.dart';
import '../models/backup_folder.dart';
import '../theme/app_theme.dart';

/// Rounded settings card for folder selection (matches [StorageUsageCard] look).
class FoldersBackupCard extends StatelessWidget {
  const FoldersBackupCard({
    super.key,
    required this.folders,
    required this.manualController,
    required this.picking,
    required this.onPickFolder,
    required this.onAddPath,
    required this.onRemoveFolder,
    required this.onChangeAlbum,
  });

  final List<BackupFolder> folders;
  final TextEditingController manualController;
  final bool picking;
  final VoidCallback onPickFolder;
  final VoidCallback onAddPath;
  final ValueChanged<String> onRemoveFolder;
  final ValueChanged<BackupFolder> onChangeAlbum;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final count = folders.length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.foxOrange.withValues(alpha: 0.95),
                        AppTheme.foxAmber,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.folder_special_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.foldersToBackUp,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      Text(
                        count == 0
                            ? s.noFoldersSelectedYet
                            : count == 1
                            ? s.oneFolderWatched()
                            : s.foldersWatched(count),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.foxOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.foxOrange,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.foldersHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.foxOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  s.webFolderHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (folders.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.create_new_folder_outlined,
                      size: 36,
                      color: AppTheme.foxOrange.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.addPhotoFolderHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...folders.map((folder) {
                final albumLabel = folder.hasAlbum
                    ? s.albumAssigned(
                        folder.albumTitle?.isNotEmpty == true
                            ? folder.albumTitle!
                            : '#${folder.albumId}',
                      )
                    : s.noAlbumHint;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.foxOrange.withValues(alpha: 0.12),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.foxOrange.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.folder_outlined,
                          color: AppTheme.foxOrange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        folder.path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            folder.hasAlbum
                                ? Icons.collections_bookmark_outlined
                                : Icons.photo_library_outlined,
                            size: 14,
                            color: folder.hasAlbum
                                ? AppTheme.foxOrange
                                : scheme.onSurface.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              albumLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: folder.hasAlbum
                                        ? AppTheme.foxOrange
                                        : scheme.onSurface.withValues(
                                            alpha: 0.55,
                                          ),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.changeAlbumTooltip,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => onChangeAlbum(folder),
                          ),
                          IconButton(
                            tooltip: s.removeFolderTooltip,
                            icon: Icon(
                              Icons.close_rounded,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                            onPressed: () => onRemoveFolder(folder.path),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: picking ? null : onPickFolder,
              icon: picking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.create_new_folder_outlined),
              label: Text(kIsWeb ? s.pickFolderNotOnWeb : s.pickFolder),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: manualController,
              decoration: InputDecoration(
                labelText: kIsWeb ? s.pastePathLabelWeb : s.pastePathLabel,
                hintText: kIsWeb ? s.pastePathHintWeb : s.pastePathHint,
                prefixIcon: const Icon(Icons.link_outlined),
                isDense: true,
              ),
              onSubmitted: (_) => onAddPath(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddPath,
              icon: const Icon(Icons.add),
              label: Text(s.addPath),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.foxOrange,
                side: BorderSide(
                  color: AppTheme.foxOrange.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
