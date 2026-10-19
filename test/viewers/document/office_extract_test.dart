import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_reader/viewers/document/office_extract.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal OOXML zip from name→content parts. Verified to extract via
/// docx_to_text / spreadsheet_decoder (see plan research), so no binary fixture
/// needs to live in the repo.
Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, c) {
    final b = c.codeUnits;
    a.addFile(ArchiveFile(n, b.length, b));
  });
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

Uint8List _docx() => _zip(<String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>',
      'word/document.xml':
          '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Hello Doc</w:t></w:r></w:p></w:body></w:document>',
    });

Uint8List _xlsx() => _zip(<String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':
          '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="S1" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/worksheets/sheet1.xml':
          '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>A</t></is></c><c r="B1" t="inlineStr"><is><t>B</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>1</t></is></c><c r="B2" t="inlineStr"><is><t>2</t></is></c></row></sheetData></worksheet>',
    });

Uint8List _xlsxTwoSheets() => _zip(<String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':
          '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/></Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Budget" sheetId="1" r:id="rId1"/><sheet name="Notes" sheetId="2" r:id="rId2"/></sheets></workbook>',
      'xl/worksheets/sheet1.xml':
          '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Month</t></is></c><c r="B1" t="inlineStr"><is><t>Total</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>Jan</t></is></c><c r="B2" t="inlineStr"><is><t>100</t></is></c></row></sheetData></worksheet>',
      'xl/worksheets/sheet2.xml':
          '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Hello</t></is></c></row></sheetData></worksheet>',
    });

void main() {
  group('extractDocxText', () {
    test('extracts text from a minimal docx', () {
      expect(extractDocxText(_docx()), contains('Hello Doc'));
    });
    test('empty input -> empty, no throw', () {
      expect(extractDocxText(<int>[]), '');
    });
    test('malformed (non-zip) bytes -> empty, no throw', () {
      expect(extractDocxText(List<int>.filled(128, 65)), '');
    });
    test('oversized input -> empty (capped)', () {
      expect(extractDocxText(_docx(), maxBytes: 4), '');
    });
  });

  group('extractXlsxTable', () {
    test('extracts rows from a minimal xlsx', () {
      final rows = extractXlsxTable(_xlsx());
      expect(rows.length, 2);
      expect(rows.first, <String>['A', 'B']);
      expect(rows[1], <String>['1', '2']);
    });
    test('empty input -> empty, no throw', () {
      expect(extractXlsxTable(<int>[]), isEmpty);
    });
    test('malformed (non-zip) bytes -> empty, no throw', () {
      expect(extractXlsxTable(List<int>.filled(128, 66)), isEmpty);
    });
    test('oversized input -> empty (capped)', () {
      expect(extractXlsxTable(_xlsx(), maxBytes: 4), isEmpty);
    });
  });

  group('extractXlsxWorkbook', () {
    test('returns all sheets in order with their rows', () {
      final wb = extractXlsxWorkbook(_xlsxTwoSheets());
      expect(wb.map((s) => s.name).toList(), <String>['Budget', 'Notes']);
      expect(wb[0].rows, <List<String>>[
        <String>['Month', 'Total'],
        <String>['Jan', '100'],
      ]);
      expect(wb[1].rows, <List<String>>[
        <String>['Hello'],
      ]);
    });

    test('single-sheet workbook returns one sheet', () {
      final wb = extractXlsxWorkbook(_xlsx());
      expect(wb.length, 1);
    });

    test('malformed / empty / oversized -> empty, no throw', () {
      expect(extractXlsxWorkbook(List<int>.filled(128, 9)), isEmpty);
      expect(extractXlsxWorkbook(<int>[]), isEmpty);
      expect(extractXlsxWorkbook(_xlsxTwoSheets(), maxBytes: 4), isEmpty);
    });
  });

  group('columnLabel', () {
    test('maps indices to Excel bijective base-26 letters', () {
      expect(columnLabel(0), 'A');
      expect(columnLabel(25), 'Z');
      expect(columnLabel(26), 'AA');
      expect(columnLabel(27), 'AB');
      expect(columnLabel(51), 'AZ');
      expect(columnLabel(701), 'ZZ');
      expect(columnLabel(702), 'AAA');
      expect(columnLabel(-1), '');
    });
  });
}
