import 'package:file_reader/viewers/text/rtf_to_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rtfToText', () {
    test('extracts body text, skipping tables and control words', () {
      const rtf =
          r'{\rtf1\ansi\deff0 {\fonttbl{\f0 Times;}}\f0\fs24 Hello, '
          r'\b World\b0!\par Second line.\par}';
      final text = rtfToText(rtf);
      expect(text, 'Hello, World!\nSecond line.');
      expect(text.contains('Times'), isFalse); // font table skipped
    });

    test('decodes \\par into newlines', () {
      expect(rtfToText(r'{\rtf1 a\par b}'), 'a\nb');
    });

    test('skips ignorable \\* destination groups', () {
      const rtf = r'{\rtf1 keep{\*\generator Foo 1.0;}text}';
      final text = rtfToText(rtf);
      expect(text.contains('Foo'), isFalse);
      expect(text.contains('keep'), isTrue);
      expect(text.contains('text'), isTrue);
    });

    test('empty input -> empty, no throw', () {
      expect(rtfToText(''), '');
    });

    test('malformed input -> best-effort, no throw', () {
      expect(rtfToText(r'{\rtf1 broken'), 'broken');
    });

    test('oversized input is truncated first', () {
      final big = '{\\rtf1 ${'a' * (kMaxRtfChars + 100)}}';
      final text = rtfToText(big);
      expect(text.length <= kMaxRtfChars, isTrue);
    });
  });
}
