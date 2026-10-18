import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/reading/epub_book.dart';
import 'package:file_reader/viewers/reading/epub_viewer.dart';
import 'package:file_reader/viewers/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

Widget _host(Widget child) => MaterialApp(home: child);

const _epubRef =
    FileRef(path: '/x/book.epub', name: 'book.epub', type: FileType.epub);

void main() {
  testWidgets('EpubViewer renders injected chapters with nav', (tester) async {
    await tester.pumpWidget(_host(EpubViewer(
      file: _epubRef,
      chapters: const <EpubChapterText>[
        EpubChapterText(title: 'Chapter One', html: '<p>Hello book</p>'),
        EpubChapterText(title: 'Chapter Two', html: '<p>Second</p>'),
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.text('book.epub'), findsOneWidget);
    // Chapter title (plain Text in the nav bar) proves the chapter rendered.
    // (Body is rendered by HtmlWidget as RichText, not a findable Text node.)
    expect(find.text('Chapter One'), findsOneWidget);
    expect(find.byType(HtmlWidget), findsOneWidget);
    // Advance to the next chapter.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Chapter Two'), findsOneWidget);
  });

  testWidgets('EpubViewer shows a message when there are no chapters',
      (tester) async {
    await tester.pumpWidget(_host(const EpubViewer(
      file: _epubRef,
      chapters: <EpubChapterText>[],
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't read this e-book"), findsOneWidget);
  });

  test('registry resolves epub/svg/rtf (Phase 5)', () {
    final r = buildPhase1Registry();
    for (final t in <FileType>[FileType.epub, FileType.svg, FileType.rtf]) {
      expect(r.isSupported(t), isTrue, reason: '$t');
      expect(r.resolve(t), isNotNull, reason: '$t');
    }
  });
}
