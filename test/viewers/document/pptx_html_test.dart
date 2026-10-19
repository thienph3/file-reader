import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_reader/viewers/document/pptx_html.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pptx(Map<String, String> parts, {Map<String, List<int>>? media}) {
  final a = Archive();
  void add(String n, List<int> b) => a.addFile(ArchiveFile(n, b.length, b));
  parts.forEach((n, c) => add(n, c.codeUnits));
  media?.forEach(add);
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

String _slide(String spTreeInner) =>
    '<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:cSld><p:spTree>$spTreeInner</p:spTree></p:cSld></p:sld>';

String _txt(String inner) => '<p:sp><p:txBody>$inner</p:txBody></p:sp>';

void main() {
  group('pptxToHtmlSlides — styled text', () {
    test('bold + color + size run', () {
      final html = pptxToHtmlSlides(_pptx(<String, String>{
        'ppt/slides/slide1.xml': _slide(_txt(
            '<a:p><a:r><a:rPr b="1" sz="2400"><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:rPr><a:t>T</a:t></a:r></a:p>')),
      })).first.html;
      expect(html, contains('<strong>'));
      expect(html, contains('color:#FF0000'));
      expect(html, contains('font-size:24px')); // 2400 hundredths → 24
    });

    test('italic + underline run', () {
      final html = pptxToHtmlSlides(_pptx(<String, String>{
        'ppt/slides/slide1.xml': _slide(_txt(
            '<a:p><a:r><a:rPr i="1" u="sng"/><a:t>x</a:t></a:r></a:p>')),
      })).first.html;
      expect(html, contains('<em>'));
      expect(html, contains('<u>'));
    });

    test('invalid color dropped (no CSS injection)', () {
      final html = pptxToHtmlSlides(_pptx(<String, String>{
        'ppt/slides/slide1.xml': _slide(_txt(
            '<a:p><a:r><a:rPr><a:solidFill><a:srgbClr val="x;evil:1"/></a:solidFill></a:rPr><a:t>e</a:t></a:r></a:p>')),
      })).first.html;
      expect(html.contains('evil'), isFalse);
      expect(html.contains('style='), isFalse);
      expect(html, contains('e'));
    });
  });

  group('pptxToHtmlSlides — images & order', () {
    test('inline image embeds from per-slide rels as a data URI', () {
      final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
      final html = pptxToHtmlSlides(
        _pptx(
          <String, String>{
            'ppt/slides/slide1.xml': _slide(
                '<p:pic><p:blipFill><a:blip r:embed="rId2"/></p:blipFill></p:pic>'),
            'ppt/slides/_rels/slide1.xml.rels':
                '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId2" Type="x" Target="../media/image1.png"/></Relationships>',
          },
          media: <String, List<int>>{'ppt/media/image1.png': png},
        ),
      ).first.html;
      expect(html, contains('<img src="data:image/png;base64,'));
    });

    test('slides returned in numeric order (10 after 2)', () {
      final html = pptxToHtmlSlides(_pptx(<String, String>{
        'ppt/slides/slide2.xml':
            _slide(_txt('<a:p><a:r><a:t>two</a:t></a:r></a:p>')),
        'ppt/slides/slide10.xml':
            _slide(_txt('<a:p><a:r><a:t>ten</a:t></a:r></a:p>')),
      }));
      expect(html.map((s) => s.index).toList(), <int>[2, 10]);
    });
  });

  group('pptxToHtmlSlides — safety', () {
    test('malformed / empty / oversized -> empty, no throw', () {
      expect(pptxToHtmlSlides(<int>[1, 2, 3]), isEmpty);
      expect(pptxToHtmlSlides(<int>[]), isEmpty);
      final ok = _pptx(<String, String>{
        'ppt/slides/slide1.xml':
            _slide(_txt('<a:p><a:r><a:t>x</a:t></a:r></a:p>')),
      });
      expect(pptxToHtmlSlides(ok, maxBytes: 4), isEmpty);
    });
  });
}
