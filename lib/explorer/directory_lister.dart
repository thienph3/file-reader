import 'dart:io';

import '../core/file_ref.dart';
import '../core/file_type.dart';

/// A single row in the explorer: either a directory or a file.
class Entry {
  const Entry.directory(this.name, this.path)
      : isDirectory = true,
        fileRef = null;
  Entry.file(FileRef ref)
      : isDirectory = false,
        name = ref.name,
        path = ref.path,
        fileRef = ref;

  final bool isDirectory;
  final String name;
  final String path;

  /// Populated for files only; carries the detected [FileType].
  final FileRef? fileRef;
}

/// Lists [dirPath], returning directories first (both alphabetical).
///
/// Detection is extension-based here (no byte reads during listing — fast, and
/// avoids opening every file). Entries that can't be stat'd are skipped rather
/// than throwing, so one bad entry doesn't break the whole listing.
Future<List<Entry>> listDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  final dirs = <Entry>[];
  final files = <Entry>[];

  await for (final entity in dir.list(followLinks: false)) {
    try {
      final name = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .lastOrNull ??
          entity.path;
      if (entity is Directory) {
        dirs.add(Entry.directory(name, entity.path));
      } else if (entity is File) {
        final stat = await entity.stat();
        files.add(Entry.file(FileRef(
          path: entity.path,
          name: name,
          type: detectFileType(name),
          size: stat.size,
        )));
      }
    } catch (_) {
      // Skip unreadable entries.
    }
  }

  dirs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return <Entry>[...dirs, ...files];
}
