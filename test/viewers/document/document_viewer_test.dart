import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/document/docx_viewer.dart';
import 'package:file_reader/viewers/document/xlsx_viewer.dart';
import 'package:file_reader/viewers/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FileRef _ref(String name, FileType t) =>
    FileRef(path: '/x/$name', name: name, type: t);

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('DocxViewer shows injected extracted text', (tester) async {
    await tester.pumpWidget(_host(DocxViewer(
      file: _ref('letter.docx', FileType.docx),
      text: 'Dear team,\nThis is the body.',
    )));
    await tester.pumpAndSettle();
    expect(find.text('letter.docx'), findsOneWidget);
    expect(find.textContaining('Dear team'), findsOneWidget);
  });

  testWidgets('DocxViewer shows a message when there is no text',
      (tester) async {
    await tester.pumpWidget(_host(DocxViewer(
      file: _ref('empty.docx', FileType.docx),
      text: '',
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('No readable text'), findsOneWidget);
  });

  testWidgets('XlsxViewer renders injected rows in a table', (tester) async {
    await tester.pumpWidget(_host(XlsxViewer(
      file: _ref('budget.xlsx', FileType.xlsx),
      rows: const <List<String>>[
        <String>['Month', 'Total'],
        <String>['Jan', '1200'],
        <String>['Feb', '1240'],
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('1240'), findsOneWidget);
  });

  testWidgets('XlsxViewer caps rendered rows for a large sheet',
      (tester) async {
    final rows = <List<String>>[
      <String>['K', 'V'],
      for (var i = 0; i < kMaxXlsxRenderedRows + 25; i++)
        <String>['r$i', '$i'],
    ];
    await tester.pumpWidget(_host(XlsxViewer(
      file: _ref('big.xlsx', FileType.xlsx),
      rows: rows,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('showing the first'), findsOneWidget);
    expect(find.text('r0'), findsOneWidget);
    expect(find.text('r${kMaxXlsxRenderedRows + 24}'), findsNothing);
  });

  test('registry resolves pdf/docx/xlsx/pptx', () {
    final r = buildPhase1Registry();
    expect(r.isSupported(FileType.pdf), isTrue);
    expect(r.isSupported(FileType.docx), isTrue);
    expect(r.isSupported(FileType.xlsx), isTrue);
    expect(r.resolve(FileType.pdf), isNotNull);
    // .pptx now shows per-slide extracted text (Phase 6), no longer the modal.
    expect(r.isSupported(FileType.pptx), isTrue);
    expect(r.resolve(FileType.pptx), isNotNull);
  });
}
