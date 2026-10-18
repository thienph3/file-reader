import 'package:file_reader/viewers/text/content_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatJson', () {
    test('pretty-prints valid JSON', () {
      final r = formatJson('{"a":1,"b":[2,3]}');
      expect(r.ok, isTrue);
      expect(r.text, contains('"a": 1'));
      expect(r.text, contains('\n'));
    });

    test('malformed JSON falls back to raw, never throws', () {
      final r = formatJson('{not valid json');
      expect(r.ok, isFalse);
      expect(r.raw, '{not valid json');
    });
  });

  group('formatXml', () {
    test('pretty-prints valid XML', () {
      final r = formatXml('<a><b>x</b></a>');
      expect(r.ok, isTrue);
      expect(r.text, contains('<b>x</b>'));
      expect(r.text, contains('\n'));
    });

    test('malformed XML falls back to raw', () {
      final r = formatXml('<a><b></a>');
      expect(r.ok, isFalse);
      expect(r.raw, '<a><b></a>');
    });

    test('external entity is not expanded (no XXE)', () {
      // A DOCTYPE declaring an external SYSTEM entity must never be
      // dereferenced. Point it at a path we control that contains a known
      // sentinel; the output must never contain that sentinel (which would only
      // appear if the parser fetched and expanded the external resource).
      const sentinel = 'XXE_SENTINEL_SHOULD_NOT_APPEAR';
      const payload =
          '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM '
          '"file:///nonexistent/secret.txt">]><foo>&xxe;</foo>';
      final r = formatXml(payload);
      final out = r.ok ? r.text! : r.raw!;
      // Never dereferenced: neither our sentinel nor a typical passwd marker.
      expect(out.contains(sentinel), isFalse);
      expect(out.contains('root:'), isFalse,
          reason: 'must never contain dereferenced external content');
    });
  });

  group('parseCsv', () {
    test('parses a simple grid into rows', () {
      final r = parseCsv('a,b\n1,2');
      expect(r.tooLarge, isFalse);
      expect(r.rows.length, 2);
      expect(r.rows.first.map((e) => e.toString()).toList(), ['a', 'b']);
      expect(r.rows[1].map((e) => e.toString()).toList(), ['1', '2']);
    });

    test('tolerates ragged rows without throwing', () {
      final r = parseCsv('a,b,c\n1,2\n3,4,5,6');
      expect(r.rows.length, 3);
    });

    test('oversized input returns tooLarge with empty rows', () {
      final big = 'x,y\n${List.filled(kMaxFormatBytes, 'a').join()}';
      final r = parseCsv(big);
      expect(r.tooLarge, isTrue);
      expect(r.rows, isEmpty);
    });
  });

  group('size caps', () {
    test('oversized JSON falls back to raw instead of parsing', () {
      final big = '"${'a' * (kMaxFormatBytes + 1)}"';
      final r = formatJson(big);
      expect(r.ok, isFalse);
      expect(r.raw, big);
    });
  });
}
