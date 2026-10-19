import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/text/csv_viewer.dart';
import 'package:file_reader/viewers/text/html_viewer.dart';
import 'package:file_reader/viewers/text/structured_viewer.dart';
import 'package:file_reader/viewers/text/text_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileRef ref(String name, FileType type) =>
    FileRef(path: '/x/$name', name: name, type: type);

Widget host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('TextViewer shows content and a wrap toggle', (tester) async {
    await tester.pumpWidget(host(TextViewer(
      file: ref('notes.txt', FileType.plainText),
      content: 'hello world\nsecond line',
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('hello world'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    // Wrap is now a toggle inside the shared overflow (Options) menu.
    expect(find.byTooltip('Options'), findsOneWidget);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Wrap lines'), findsOneWidget);
  });

  testWidgets('StructuredViewer pretty-prints JSON and toggles to raw',
      (tester) async {
    await tester.pumpWidget(host(StructuredViewer(
      file: ref('config.json', FileType.json),
      content: '{"a":1}',
    )));
    await tester.pumpAndSettle();
    // Pretty output has a space after the colon.
    expect(find.textContaining('"a": 1'), findsOneWidget);
    // Toggle to RAW.
    await tester.tap(find.text('RAW'));
    await tester.pumpAndSettle();
    expect(find.textContaining('{"a":1}'), findsOneWidget);
  });

  testWidgets('StructuredViewer falls back to raw for malformed JSON',
      (tester) async {
    await tester.pumpWidget(host(StructuredViewer(
      file: ref('bad.json', FileType.json),
      content: '{nope',
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't parse"), findsOneWidget);
    expect(find.textContaining('{nope'), findsOneWidget);
  });

  testWidgets('CsvViewer renders a table with header and rows',
      (tester) async {
    await tester.pumpWidget(host(CsvViewer(
      file: ref('d.csv', FileType.csv),
      content: 'Name,Age\nAlice,30\nBob,25',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('CsvViewer caps rendered rows for a large table', (tester) async {
    // Build a within-byte-cap CSV with more rows than kMaxCsvRenderedRows.
    final rows = <String>['Name,Value'];
    for (var i = 0; i < kMaxCsvRenderedRows + 50; i++) {
      rows.add('row$i,$i');
    }
    await tester.pumpWidget(host(CsvViewer(
      file: ref('big.csv', FileType.csv),
      content: rows.join('\n'),
    )));
    await tester.pumpAndSettle();
    // The cap banner names the limit; first row visible, capped row not built.
    expect(find.textContaining('showing the first'), findsOneWidget);
    expect(find.text('row0'), findsOneWidget);
    expect(find.text('row${kMaxCsvRenderedRows + 49}'), findsNothing);
  });

  testWidgets('HtmlViewer renders and toggles to raw', (tester) async {
    await tester.pumpWidget(host(HtmlViewer(
      file: ref('index.html', FileType.html),
      content: '<h2>Welcome</h2><p>Hi</p>',
    )));
    await tester.pumpAndSettle();
    expect(find.text('VIEW'), findsOneWidget);
    await tester.tap(find.text('RAW'));
    await tester.pumpAndSettle();
    expect(find.textContaining('<h2>Welcome</h2>'), findsOneWidget);
  });
}
