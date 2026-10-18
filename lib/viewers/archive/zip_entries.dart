import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A safe, listable entry inside a zip (file entries only; unsafe entries are
/// excluded entirely — see [listZipEntries]).
class ZipEntry {
  const ZipEntry({required this.name, required this.size});
  final String name;
  final int size;
}

/// Max bytes of a zip archive read into memory for listing.
///
/// SHORTCUT: flat cap bounds memory for the whole archive buffer. Ceiling named
/// per the Threat Model (decompression-bomb / huge-archive DoS).
const int kMaxArchiveBytes = 64 * 1024 * 1024;

/// Max inflated size of a single inner entry previewed in memory.
///
/// SHORTCUT: per-entry inflate cap — the real zip-bomb guard, since listing
/// never inflates and preview inflates exactly one entry. Raise if needed.
const int kMaxEntryBytes = 8 * 1024 * 1024;

/// True if [name] is unsafe to surface: absolute path, parent traversal, or an
/// empty/odd name. Symlink handling is done at the entry level (isSymbolicLink).
bool _unsafeName(String name) {
  if (name.isEmpty) return true;
  if (name.startsWith('/') || name.startsWith('\\')) return true; // absolute
  final segments = name.split(RegExp(r'[/\\]'));
  for (final s in segments) {
    if (s == '..') return true; // parent traversal
  }
  // Windows drive-absolute like C:\ or C:/
  if (RegExp(r'^[a-zA-Z]:').hasMatch(name)) return true;
  return false;
}

/// Lists the *safe file* entries of a zip WITHOUT inflating any content.
///
/// Excludes directories, symlinks, and unsafe names (absolute paths, `..`
/// traversal, drive-absolute). Oversized archive or malformed bytes → empty.
/// Never throws.
List<ZipEntry> listZipEntries(
  List<int> bytes, {
  int maxBytes = kMaxArchiveBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return const <ZipEntry>[];
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final out = <ZipEntry>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.isSymbolicLink) continue;
      if (_unsafeName(f.name)) continue;
      out.add(ZipEntry(name: f.name, size: f.size));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  } catch (_) {
    return const <ZipEntry>[];
  }
}

/// Inflates exactly ONE entry named [name] into memory, bounded by
/// [maxEntryBytes]. Returns null if the entry is missing, unsafe, a symlink, a
/// directory, or exceeds the cap. Never throws. Nothing is written to disk.
Uint8List? readZipEntry(
  List<int> bytes,
  String name, {
  int maxBytes = kMaxArchiveBytes,
  int maxEntryBytes = kMaxEntryBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return null;
  if (_unsafeName(name)) return null;
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final f in archive.files) {
      if (f.name != name) continue;
      if (!f.isFile || f.isSymbolicLink) return null;
      if (f.size > maxEntryBytes) return null; // zip-bomb bound
      final content = f.content;
      if (content is! List<int>) return null;
      if (content.length > maxEntryBytes) return null;
      return Uint8List.fromList(content);
    }
    return null;
  } catch (_) {
    return null;
  }
}
