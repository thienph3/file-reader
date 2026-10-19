import 'dart:io';

import '../core/file_ref.dart';
import '../core/file_type.dart';

/// A single row in the explorer: either a directory or a file.
class Entry {
  Entry.directory(this.name, this.path, {this.modified})
      : isDirectory = true,
        size = null,
        fileRef = null;
  Entry.file(FileRef ref, {this.modified})
      : isDirectory = false,
        name = ref.name,
        path = ref.path,
        size = ref.size,
        fileRef = ref;

  final bool isDirectory;
  final String name;
  final String path;

  /// File size in bytes; null for directories.
  final int? size;

  /// Last-modified time if known; used by date sorting + the detail view.
  final DateTime? modified;

  /// Populated for files only; carries the detected [FileType].
  final FileRef? fileRef;

  /// True if this is a hidden entry (dotfile), e.g. `.gitignore`.
  bool get isHidden => name.startsWith('.');
}

/// Lists [dirPath] as a flat list of [Entry] (unsorted — ordering/visibility is
/// applied by `explorer_sort.dart` so the user's sort/filter prefs decide it).
///
/// Detection is extension-based here (no byte reads during listing — fast, and
/// avoids opening every file). Entries that can't be stat'd are skipped rather
/// than throwing, so one bad entry doesn't break the whole listing.
Future<List<Entry>> listDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  final entries = <Entry>[];

  await for (final entity in dir.list(followLinks: false)) {
    try {
      final name = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .lastOrNull ??
          entity.path;
      final stat = await entity.stat();
      if (entity is Directory) {
        entries.add(Entry.directory(name, entity.path,
            modified: stat.modified));
      } else if (entity is File) {
        entries.add(Entry.file(
          FileRef(
            path: entity.path,
            name: name,
            type: detectFileType(name),
            size: stat.size,
          ),
          modified: stat.modified,
        ));
      }
    } catch (_) {
      // Skip unreadable entries.
    }
  }
  return entries;
}
