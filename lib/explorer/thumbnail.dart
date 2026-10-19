import 'dart:io';

import 'package:flutter/material.dart';

import 'directory_lister.dart';
import 'entry_visuals.dart';

/// A square visual for an explorer entry: a real image thumbnail for decodable
/// images, otherwise the category icon.
///
/// Thumbnails are bounded: `cacheWidth` caps decode resolution so a huge image
/// doesn't blow memory, and `errorBuilder` falls back to the icon if decode
/// fails (e.g. a corrupt or unsupported image). Lazy by construction — only the
/// tiles a ListView/GridView actually builds will decode.
class EntryThumbnail extends StatelessWidget {
  const EntryThumbnail({super.key, required this.entry, this.size = 40});

  final Entry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (hasThumbnail(entry)) {
      // Decode at ~2x the display size for crispness, capped.
      final cap = (size * 2).round().clamp(64, 512);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(entry.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cap,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _IconBox(entry: entry, size: size),
        ),
      );
    }
    return _IconBox(entry: entry, size: size);
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.entry, required this.size});
  final Entry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(iconFor(entry), size: size * 0.6),
    );
  }
}
