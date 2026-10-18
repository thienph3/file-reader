import 'file_type.dart';

/// An immutable reference to a file the user opened, carrying only what a
/// viewer needs to render it. Never holds file *contents* — viewers read
/// bytes lazily from [path] so large files don't sit in memory.
class FileRef {
  const FileRef({
    required this.path,
    required this.name,
    required this.type,
    this.size,
  });

  /// Absolute filesystem path (`file://`-style) or a content URI string.
  final String path;

  /// Display name (final path segment), e.g. `budget.csv`.
  final String name;

  /// Detected format family. See [detectFileType].
  final FileType type;

  /// Size in bytes if known; null when it cannot be determined cheaply
  /// (e.g. a `content://` URI without a stat).
  final int? size;

  @override
  bool operator ==(Object other) =>
      other is FileRef &&
      other.path == path &&
      other.name == name &&
      other.type == type &&
      other.size == size;

  @override
  int get hashCode => Object.hash(path, name, type, size);

  @override
  String toString() => 'FileRef($name, $type, ${size ?? '?'}B)';
}
