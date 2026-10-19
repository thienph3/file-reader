import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_reader/viewers/document/docx_html.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a .docx from word/document.xml (+ optional rels/media parts).
Uint8List _docx(String documentXml,
    {String? rels, Map<String, List<int>>? media}) {
  final a = Archive();
  void add(String n, List<int> b) => a.addFile(ArchiveFile(n, b.length, b));
  add('[Content_Types].xml',
      '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>'
          .codeUnits);
  add('word/document.xml', documentXml.codeUnits);
  if (rels != null) add('word/_rels/document.xml.rels', rels.codeUnits);
  media?.forEach(add);
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

String _body(String inner) =>
    '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>$inner</w:body></w:document>';

void main() {
  group('docxToHtml — structure', () {
    test('heading style -> <hN>', () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Sec</w:t></w:r></w:p>')));
      expect(html, contains('<h2>Sec</h2>'));
    });

    test('bold / italic / underline runs', () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>b</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t>i</w:t></w:r><w:r><w:rPr><w:u w:val="single"/></w:rPr><w:t>u</w:t></w:r></w:p>')));
      expect(html, contains('<strong>b</strong>'));
      expect(html, contains('<em>i</em>'));
      expect(html, contains('<u>u</u>'));
    });

    test('numPr paragraphs group into a <ul> of <li>', () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:pPr><w:numPr><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>one</w:t></w:r></w:p>'
          '<w:p><w:pPr><w:numPr><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>two</w:t></w:r></w:p>')));
      expect(html, contains('<ul><li>one</li><li>two</li></ul>'));
    });

    test('table -> <table><tr><td>, not double-emitted as paragraphs', () {
      final html = docxToHtml(_docx(_body(
          '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc></w:tr></w:tbl>')));
      expect(html, contains('<table><tr><td>A1</td><td>B1</td></tr></table>'));
      // The cell text must not also appear as a stray top-level <p>.
      expect(html.contains('<p>A1</p>'), isFalse);
    });

    test('escapes HTML-special characters in text', () {
      final html = docxToHtml(
          _docx(_body('<w:p><w:r><w:t>a &lt; b &amp; c</w:t></w:r></w:p>')));
      // Decoded XML text is "a < b & c"; re-escaped for HTML output.
      expect(html, contains('a &lt; b &amp; c'));
      expect(html.contains('<p>a < b'), isFalse);
    });

    test('inline image embeds as a data URI from word/media via rels', () {
      final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
      final html = docxToHtml(_docx(
        _body(
            '<w:p><w:r><w:drawing><a:blip r:embed="rId5"/></w:drawing></w:r></w:p>'),
        rels:
            '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/></Relationships>',
        media: <String, List<int>>{'word/media/image1.png': png},
      ));
      expect(html, contains('<img src="data:image/png;base64,'));
    });

    test('oversized inline image is skipped (not embedded)', () {
      final big = List<int>.filled(100, 0);
      final html = docxToHtml(
        _docx(
          _body(
              '<w:p><w:r><w:drawing><a:blip r:embed="rId5"/></w:drawing></w:r></w:p>'),
          rels:
              '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId5" Type="x" Target="media/image1.png"/></Relationships>',
          media: <String, List<int>>{'word/media/image1.png': big},
        ),
        maxImageBytes: 10,
      );
      expect(html.contains('<img'), isFalse);
    });
  });

  group('docxToHtml — color / size / highlight / alignment', () {
    test('valid color, size, highlight, and alignment -> sanitized styles', () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:color w:val="FF0000"/><w:sz w:val="36"/><w:highlight w:val="yellow"/></w:rPr><w:t>hi</w:t></w:r></w:p>')));
      expect(html, contains('text-align:center'));
      expect(html, contains('color:#FF0000'));
      expect(html, contains('font-size:18px')); // 36 half-points → 18px
      expect(html, contains('background-color:#ffff00'));
    });

    test('invalid color value is dropped (no CSS injection)', () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:r><w:rPr><w:color w:val="red;x:expression(alert(1))"/></w:rPr><w:t>evil</w:t></w:r></w:p>')));
      expect(html.contains('expression'), isFalse);
      expect(html.contains('style='), isFalse); // nothing emitted
      expect(html, contains('evil'));
    });

    test("color 'auto' is dropped", () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:r><w:rPr><w:color w:val="auto"/></w:rPr><w:t>a</w:t></w:r></w:p>')));
      expect(html.contains('color:'), isFalse);
    });

    test('non-whitelisted alignment / highlight are dropped', () {
      final align = docxToHtml(_docx(_body(
          '<w:p><w:pPr><w:jc w:val="evil"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>')));
      expect(align.contains('text-align'), isFalse);
      final hl = docxToHtml(_docx(_body(
          '<w:p><w:r><w:rPr><w:highlight w:val="notacolor"/></w:rPr><w:t>y</w:t></w:r></w:p>')));
      expect(hl.contains('background-color'), isFalse);
    });

    test('font size is clamped to a sane range', () {
      final html = docxToHtml(_docx(_body(
          '<w:p><w:r><w:rPr><w:sz w:val="99999"/></w:rPr><w:t>big</w:t></w:r></w:p>')));
      expect(html, contains('font-size:96px')); // clamped max
    });
  });

  group('docxToHtml — safety', () {
    test('malformed (non-zip) bytes -> empty, no throw', () {
      expect(docxToHtml(<int>[1, 2, 3, 4]), '');
    });
    test('empty input -> empty', () {
      expect(docxToHtml(<int>[]), '');
    });
    test('oversized input -> empty (capped)', () {
      expect(docxToHtml(_docx(_body('<w:p><w:r><w:t>x</w:t></w:r></w:p>')),
          maxBytes: 4), '');
    });
    test('zip without word/document.xml -> empty', () {
      final a = Archive();
      final b = 'nope'.codeUnits;
      a.addFile(ArchiveFile('other.xml', b.length, b));
      expect(docxToHtml(Uint8List.fromList(ZipEncoder().encode(a)!)), '');
    });
  });
}
