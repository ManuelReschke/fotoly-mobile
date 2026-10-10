import 'package:file_picker/file_picker.dart';

/// One local image chosen for an album upload.
class AlbumUploadFile {
  const AlbumUploadFile({required this.filename, required this.bytes});

  final String filename;
  final List<int> bytes;
}

/// Opens the platform image picker. Returns an empty list when cancelled.
Future<List<AlbumUploadFile>> pickAlbumUploadFiles() async {
  final result = await FilePicker.pickFiles(type: FileType.image);
  if (result == null) return const [];
  final files = <AlbumUploadFile>[];
  for (final file in result.files) {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) continue;
    final name = file.name.trim().isEmpty ? 'image.jpg' : file.name.trim();
    files.add(AlbumUploadFile(filename: name, bytes: bytes));
  }
  return files;
}
