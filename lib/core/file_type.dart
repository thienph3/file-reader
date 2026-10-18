import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

/// A family of file formats the app knows how to classify.
///
/// Detection is extension-first (fast, no I/O) with a MIME / magic-byte
/// fallback for files whose name has no extension or an extension that lies.
/// [unsupported] is the terminal "we cannot read this yet" bucket — the
/// explorer shows the Unsupported-file modal for it rather than pushing a
/// viewer. See `.kiro/delivery/2026-10-18-flutter-file-reader/plan.md`.
enum FileType {
  plainText,
  markdown,
  json,
  xml,
  csv,
  html,
  image,
  pdf,
  docx,
  xlsx,
  pptx,
  audio,
  video,
  archive,
  epub,
  svg,
  rtf,
  unsupported,
}

/// Maps a lower-case extension (without the dot) to a [FileType].
///
/// Phase 1 scope only. `.md` maps to [FileType.markdown] so the type survives,
/// but Phase 1 routes it to the plain-text viewer (rich Markdown is Phase 5).
const Map<String, FileType> _extensionMap = <String, FileType>{
  'txt': FileType.plainText,
  'log': FileType.plainText,
  'md': FileType.markdown,
  'json': FileType.json,
  'xml': FileType.xml,
  'csv': FileType.csv,
  'html': FileType.html,
  'htm': FileType.html,
  // Phase 2 — image family.
  'jpg': FileType.image,
  'jpeg': FileType.image,
  'png': FileType.image,
  'gif': FileType.image,
  'webp': FileType.image,
  'bmp': FileType.image,
  'heic': FileType.image,
  // Phase 3 — document family.
  'pdf': FileType.pdf,
  'docx': FileType.docx,
  'xlsx': FileType.xlsx,
  'pptx': FileType.pptx,
  // Phase 4 — media & archives.
  'mp3': FileType.audio,
  'm4a': FileType.audio,
  'wav': FileType.audio,
  'ogg': FileType.audio,
  'mp4': FileType.video,
  'mkv': FileType.video,
  'webm': FileType.video,
  'zip': FileType.archive,
  // Phase 5 — reading & long tail.
  'epub': FileType.epub,
  'svg': FileType.svg,
  'cbz': FileType.archive, // comic/manga = zip of images → archive browser
  // Config / markup (open as text).
  'yaml': FileType.plainText,
  'yml': FileType.plainText,
  'toml': FileType.plainText,
  'ini': FileType.plainText,
  'properties': FileType.plainText,
  'env': FileType.plainText,
  'conf': FileType.plainText,
  'cfg': FileType.plainText,
  'rtf': FileType.rtf, // rich text → extracted plain text (RtfViewer)
  // Source code (open as text).
  'dart': FileType.plainText,
  'py': FileType.plainText,
  'js': FileType.plainText,
  'ts': FileType.plainText,
  'jsx': FileType.plainText,
  'tsx': FileType.plainText,
  'java': FileType.plainText,
  'kt': FileType.plainText,
  'c': FileType.plainText,
  'h': FileType.plainText,
  'cpp': FileType.plainText,
  'cc': FileType.plainText,
  'hpp': FileType.plainText,
  'cs': FileType.plainText,
  'go': FileType.plainText,
  'rs': FileType.plainText,
  'rb': FileType.plainText,
  'php': FileType.plainText,
  'swift': FileType.plainText,
  'sh': FileType.plainText,
  'bash': FileType.plainText,
  'sql': FileType.plainText,
  'css': FileType.plainText,
  'scss': FileType.plainText,
};

/// Maps a MIME type (as returned by `package:mime`) to a [FileType], used when
/// the extension is absent or unrecognised.
const Map<String, FileType> _mimeMap = <String, FileType>{
  'text/plain': FileType.plainText,
  'text/markdown': FileType.markdown,
  'application/json': FileType.json,
  'text/json': FileType.json,
  'application/xml': FileType.xml,
  'text/xml': FileType.xml,
  'text/csv': FileType.csv,
  'text/html': FileType.html,
  // Phase 2 — image family (magic-byte/MIME fallback for no-extension images).
  'image/jpeg': FileType.image,
  'image/png': FileType.image,
  'image/gif': FileType.image,
  'image/webp': FileType.image,
  'image/bmp': FileType.image,
  'image/x-ms-bmp': FileType.image,
  'image/heic': FileType.image,
  'image/heif': FileType.image,
  // Phase 3 — document family (OpenXML + PDF MIME types).
  'application/pdf': FileType.pdf,
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      FileType.docx,
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      FileType.xlsx,
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      FileType.pptx,
  // Phase 4 — media & archives.
  'audio/mpeg': FileType.audio,
  'audio/mp4': FileType.audio,
  'audio/x-m4a': FileType.audio,
  'audio/wav': FileType.audio,
  'audio/x-wav': FileType.audio,
  'audio/ogg': FileType.audio,
  'video/mp4': FileType.video,
  'video/x-matroska': FileType.video,
  'video/webm': FileType.video,
  'application/zip': FileType.archive,
  'application/x-zip-compressed': FileType.archive,
  // Phase 5.
  'application/epub+zip': FileType.epub,
  'image/svg+xml': FileType.svg,
};

/// Detects the [FileType] of a file from its [fileName] (or path), optionally
/// using the first bytes of the file for a magic-byte fallback.
///
/// Resolution order:
/// 1. Known extension → its mapped type.
/// 2. Otherwise, MIME lookup (extension + optional [headerBytes]) → mapped type.
/// 3. Otherwise → [FileType.unsupported].
///
/// [fileName] may be a bare name or a full path; only the final segment's
/// extension is used. [headerBytes] should be the first ~16 bytes of the file
/// when available; it is only consulted when the extension does not resolve.
FileType detectFileType(String fileName, {List<int>? headerBytes}) {
  final String ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  final FileType? byExt = _extensionMap[ext];
  if (byExt != null) {
    return byExt;
  }

  final String? mime =
      lookupMimeType(fileName, headerBytes: headerBytes)?.toLowerCase();
  if (mime != null) {
    final FileType? byMime = _mimeMap[mime];
    if (byMime != null) {
      return byMime;
    }
  }

  return FileType.unsupported;
}
