import 'package:flutter/material.dart';

import '../core/file_type.dart';
import 'directory_lister.dart';

/// The image families that have real thumbnails (platform-decodable). HEIC is
/// excluded — its decode is device-dependent, so it uses the icon.
const Set<String> _thumbnailExtensions = <String>{
  'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
};

/// Whether [entry] is an image we should try to render a thumbnail for.
bool hasThumbnail(Entry entry) {
  if (entry.isDirectory || entry.fileRef?.type != FileType.image) return false;
  final name = entry.name.toLowerCase();
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return _thumbnailExtensions.contains(name.substring(dot + 1));
}

/// A category icon for an entry (used when there is no thumbnail).
IconData iconFor(Entry entry) {
  if (entry.isDirectory) return Icons.folder;
  switch (entry.fileRef?.type) {
    case FileType.image:
      return Icons.image_outlined;
    case FileType.pdf:
      return Icons.picture_as_pdf_outlined;
    case FileType.docx:
    case FileType.rtf:
      return Icons.description_outlined;
    case FileType.xlsx:
    case FileType.csv:
      return Icons.table_chart_outlined;
    case FileType.pptx:
      return Icons.slideshow_outlined;
    case FileType.audio:
      return Icons.audiotrack_outlined;
    case FileType.video:
      return Icons.movie_outlined;
    case FileType.archive:
      return Icons.folder_zip_outlined;
    case FileType.epub:
      return Icons.menu_book_outlined;
    case FileType.svg:
      return Icons.polyline_outlined;
    case FileType.json:
    case FileType.xml:
    case FileType.html:
    case FileType.markdown:
    case FileType.plainText:
      return Icons.description_outlined;
    case FileType.unsupported:
    case null:
      return Icons.insert_drive_file_outlined;
  }
}

/// Human-readable byte size (e.g. "2.0 MB"). Null/negative → ''.
String formatSize(int? bytes) {
  if (bytes == null || bytes < 0) return '';
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  var u = 0;
  while (size >= 1024 && u < units.length - 1) {
    size /= 1024;
    u++;
  }
  final s = u == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$s ${units[u]}';
}

/// Short date (e.g. "2026-10-19"). Null → ''.
String formatDate(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
