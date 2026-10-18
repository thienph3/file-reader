import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_reader/viewers/document/pptx_extract.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, c) {
    final b = c.codeUnits;
    a.addFile(ArchiveFile(n, b.length, b));
  });
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

String _slide(List<String> runs) =>
    '<?xml version="1.0"?><p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
    '<p:cSld><p:spTree>'
    '${runs.map((t) => '<a:t>$t</a:t>').join()}'
    '</p:spTree></p:cSld></p:sld>';

Uint8List _pptx() => _zip(<String, String>{
      'ppt/slides/slide1.xml': _slide(<String>['Title One', 'Bullet A']),
      'ppt/slides/slide2.xml': _slide(<String>['Second slide']),
      'ppt/slides/slide10.xml': _slide(<String>['Slide ten']),
      'ppt/presentation.xml': '<p:presentation/>', // non-slide entry ignored
    });

void main() {
  group('extractPptxSlides', () {
    test('extracts text per slide in NUMERIC order (slide10 after slide2)', () {
      final slides = extractPptxSlides(_pptx());
      expect(slides.map((s) => s.index).toList(), <int>[1, 2, 10]);
      expect(slides[0].texts, <String>['Title One', 'Bullet A']);
      expect(slides[1].texts, <String>['Second slide']);
      expect(slides[2].texts, <String>['Slide ten']);
    });

    test('a zip without ppt/slides/* -> empty', () {
      final z = _zip(<String, String>{'docProps/core.xml': '<x/>'});
      expect(extractPptxSlides(z), isEmpty);
    });

    test('malformed (non-zip) bytes -> empty, no throw', () {
      expect(extractPptxSlides(List<int>.filled(128, 7)), isEmpty);
    });

    test('empty input -> empty', () {
      expect(extractPptxSlides(<int>[]), isEmpty);
    });

    test('oversized input -> empty (capped)', () {
      expect(extractPptxSlides(_pptx(), maxBytes: 8), isEmpty);
    });

    test('a slide with malformed XML is kept with empty text, not fatal', () {
      final z = _zip(<String, String>{
        'ppt/slides/slide1.xml': _slide(<String>['Good']),
        'ppt/slides/slide2.xml': '<p:sld><a:t>unclosed',
      });
      final slides = extractPptxSlides(z);
      expect(slides.map((s) => s.index).toList(), <int>[1, 2]);
      expect(slides[0].texts, <String>['Good']);
      expect(slides[1].texts, isEmpty); // malformed slide → no text, no throw
    });
  });
}
