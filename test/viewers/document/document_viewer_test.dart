import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/document/docx_viewer.dart';
import 'package:file_reader/viewers/document/office_extract.dart';
import 'package:file_reader/viewers/document/xlsx_viewer.dart';
import 'package:file_reader/viewers/registry.dart';
import 'package:file_reader/viewers/viewer_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:flutter_test/flutter_test.dart';

FileRef _ref(String name, FileType t) =>
    FileRef(path: '/x/$name', name: name, type: t);

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('DocxViewer shows injected extracted text (plain fallback)',
      (tester) async {
    await tester.pumpWidget(_host(DocxViewer(
      file: _ref('letter.docx', FileType.docx),
      text: 'Dear team,\nThis is the body.',
    )));
    await tester.pumpAndSettle();
    expect(find.text('letter.docx'), findsOneWidget);
    // No html injected → shows plain text regardless of the Formatted toggle.
    expect(find.textContaining('Dear team'), findsOneWidget);
    expect(find.byType(ExtractionBadge), findsOneWidget);
  });

  testWidgets('DocxViewer renders formatted HTML and toggles to plain',
      (tester) async {
    await tester.pumpWidget(_host(DocxViewer(
      file: _ref('rich.docx', FileType.docx),
      html: '<h1>Title</h1><p><strong>bold</strong></p>',
      text: 'Title bold',
    )));
    await tester.pumpAndSettle();
    // Formatted mode (default): the HTML renderer is present.
    expect(find.byType(HtmlWidget), findsOneWidget);
    // Toggle to PLAIN → the extracted text shows, HTML renderer gone.
    await tester.tap(find.text('PLAIN'));
    await tester.pumpAndSettle();
    expect(find.byType(HtmlWidget), findsNothing);
    expect(find.textContaining('Title bold'), findsOneWidget);
  });

  testWidgets('DocxViewer shows a message when there is no content',
      (tester) async {
    await tester.pumpWidget(_host(DocxViewer(
      file: _ref('empty.docx', FileType.docx),
      text: '',
      html: '',
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('No readable content'), findsOneWidget);
  });

  testWidgets('XlsxViewer renders a grid with A/B headers and row numbers',
      (tester) async {
    await tester.pumpWidget(_host(XlsxViewer(
      file: _ref('budget.xlsx', FileType.xlsx),
      workbook: const <XlsxSheet>[
        XlsxSheet(name: 'Sheet1', rows: <List<String>>[
          <String>['Month', 'Total'],
          <String>['Jan', '1200'],
        ]),
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.byType(TableView), findsOneWidget);
    // Spreadsheet frame: column letters + row numbers are shown.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // A visible data cell.
    expect(find.text('Month'), findsOneWidget);
    expect(find.byType(ExtractionBadge), findsOneWidget);
  });

  testWidgets('XlsxViewer shows sheet tabs and switches sheets',
      (tester) async {
    await tester.pumpWidget(_host(XlsxViewer(
      file: _ref('book.xlsx', FileType.xlsx),
      workbook: const <XlsxSheet>[
        XlsxSheet(name: 'Budget', rows: <List<String>>[
          <String>['one']
        ]),
        XlsxSheet(name: 'Notes', rows: <List<String>>[
          <String>['two']
        ]),
      ],
    )));
    await tester.pumpAndSettle();
    // Both sheet tabs present; first sheet's cell visible.
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    // Switch to the second sheet.
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('XlsxViewer shows an empty state for an empty workbook',
      (tester) async {
    await tester.pumpWidget(_host(XlsxViewer(
      file: _ref('empty.xlsx', FileType.xlsx),
      workbook: const <XlsxSheet>[],
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Empty or unreadable'), findsOneWidget);
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
