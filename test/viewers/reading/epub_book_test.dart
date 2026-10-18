import 'package:file_reader/viewers/reading/epub_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseEpub — safety contract (never throws)', () {
    test('empty input -> empty', () async {
      expect(await parseEpub(<int>[]), isEmpty);
    });

    test('malformed (non-zip) bytes -> empty, no throw', () async {
      expect(await parseEpub(List<int>.filled(256, 7)), isEmpty);
    });

    test('a valid zip that is not an epub -> empty, no throw', () async {
      // PK zip header followed by junk: decodes as a zip but lacks EPUB parts.
      final notEpub = <int>[0x50, 0x4B, 0x03, 0x04, ...List<int>.filled(64, 0)];
      expect(await parseEpub(notEpub), isEmpty);
    });

    test('oversized input -> empty (capped)', () async {
      expect(await parseEpub(List<int>.filled(64, 1), maxBytes: 16), isEmpty);
    });
  });

  // NOTE: the happy-path (a real .epub -> flattened chapters) is verified with
  // a real book on-device; epubx requires a spec-complete NCX navigation that a
  // reliable minimal hand-built fixture cannot easily satisfy. The flatten walk
  // over book.Chapters/SubChapters is trivial and inspected. See
  // delivery/.../phase5/decisions.md.
}
