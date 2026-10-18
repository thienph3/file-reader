import 'dart:typed_data';

import 'package:file_reader/viewers/image/exif_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal little-endian TIFF with one ASCII IFD entry: Image Make = "X".
/// Verified to decode via `package:exif` (see plan research). Deterministic, so
/// no binary image fixture needs to live in the repo.
Uint8List _tiffWithMake() {
  final b = BytesBuilder();
  b.add(<int>[0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00]); // II, 42, IFD@8
  b.add(<int>[0x01, 0x00]); // 1 entry
  // tag 0x010F (Make), type 2 ASCII, count 2, inline value "X\0"
  b.add(<int>[0x0F, 0x01, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x58, 0x00, 0x00, 0x00]);
  b.add(<int>[0x00, 0x00, 0x00, 0x00]); // next IFD = 0
  return b.toBytes();
}

void main() {
  group('readExifEntries', () {
    test('decodes valid EXIF into entries', () async {
      final entries = await readExifEntries(_tiffWithMake());
      expect(entries, isNotEmpty);
      final make = entries.firstWhere((e) => e.tag == 'Image Make');
      expect(make.value, 'X');
    });

    test('empty input returns empty, no throw', () async {
      expect(await readExifEntries(<int>[]), isEmpty);
    });

    test('malformed bytes return empty, never throw', () async {
      final junk = List<int>.generate(256, (i) => (i * 7) % 256);
      expect(await readExifEntries(junk), isEmpty);
    });

    test('oversized input is rejected (capped) -> empty', () async {
      final entries =
          await readExifEntries(_tiffWithMake(), maxBytes: 4);
      expect(entries, isEmpty);
    });

    test('thumbnail blobs are never emitted', () async {
      final entries = await readExifEntries(_tiffWithMake());
      expect(entries.any((e) => e.tag == 'JPEGThumbnail'), isFalse);
      expect(entries.any((e) => e.tag == 'TIFFThumbnail'), isFalse);
    });

    test('entries are sorted by tag', () async {
      final entries = await readExifEntries(_tiffWithMake());
      final tags = entries.map((e) => e.tag).toList();
      final sorted = <String>[...tags]..sort();
      expect(tags, sorted);
    });
  });
}
