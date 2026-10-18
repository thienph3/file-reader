import 'package:exif/exif.dart';

/// One decoded EXIF tag, ready to show in the panel.
class ExifEntry {
  const ExifEntry(this.tag, this.value);

  /// Human-readable tag name, e.g. `Image Make`.
  final String tag;

  /// Printable value string (from `IfdTag.printable`).
  final String value;
}

/// Max bytes of image data read for EXIF parsing.
///
/// SHORTCUT: flat cap — EXIF lives near the start of the file, so a bounded
/// read is enough for the common case; raise/stream if a format stores EXIF
/// late. Ceiling named per the Threat Model (bound DoS on untrusted bytes).
const int kMaxExifBytes = 8 * 1024 * 1024;

/// Thumbnail blobs carried in the EXIF map — raw bytes, not shown in the panel.
const Set<String> _thumbnailKeys = <String>{'JPEGThumbnail', 'TIFFThumbnail'};

/// Decodes EXIF tags from [bytes] into a sorted, display-ready list.
///
/// Safe by contract (Threat Model): never throws — malformed, absent, or
/// oversized input returns an empty list. Thumbnail blobs are dropped. Values
/// are `IfdTag.printable` strings, rendered as plain text by the panel (never
/// used as a path/URL/markup sink).
Future<List<ExifEntry>> readExifEntries(
  List<int> bytes, {
  int maxBytes = kMaxExifBytes,
}) async {
  if (bytes.isEmpty || bytes.length > maxBytes) {
    return const <ExifEntry>[];
  }
  try {
    final Map<String, IfdTag> data = await readExifFromBytes(bytes);
    final entries = <ExifEntry>[];
    for (final e in data.entries) {
      if (_thumbnailKeys.contains(e.key)) continue;
      entries.add(ExifEntry(e.key, e.value.printable));
    }
    entries.sort((a, b) => a.tag.compareTo(b.tag));
    return entries;
  } catch (_) {
    // Untrusted/malformed bytes must never crash the viewer.
    return const <ExifEntry>[];
  }
}
