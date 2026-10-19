import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/document/pptx_extract.dart';
import 'package:file_reader/viewers/document/pptx_html.dart';
import 'package:file_reader/viewers/document/pptx_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

const _ref =
    FileRef(path: '/x/deck.pptx', name: 'deck.pptx', type: FileType.pptx);

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('Formatted mode renders per-slide HTML with headers',
      (tester) async {
    await tester.pumpWidget(_host(PptxViewer(
      file: _ref,
      slidesHtml: const <PptxSlideHtml>[
        PptxSlideHtml(index: 1, html: '<p><strong>Welcome</strong></p>'),
        PptxSlideHtml(index: 2, html: '<p>Topic one</p>'),
      ],
      slidesText: const <PptxSlide>[
        PptxSlide(index: 1, texts: <String>['Welcome']),
        PptxSlide(index: 2, texts: <String>['Topic one']),
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.text('deck.pptx'), findsOneWidget);
    expect(find.text('Slide 1'), findsOneWidget);
    expect(find.text('Slide 2'), findsOneWidget);
    expect(find.byType(HtmlWidget), findsNWidgets(2)); // one per slide
  });

  testWidgets('toggles to Plain text mode', (tester) async {
    await tester.pumpWidget(_host(PptxViewer(
      file: _ref,
      slidesHtml: const <PptxSlideHtml>[
        PptxSlideHtml(index: 1, html: '<p><strong>Welcome</strong></p>'),
      ],
      slidesText: const <PptxSlide>[
        PptxSlide(index: 1, texts: <String>['Welcome plain']),
      ],
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAIN'));
    await tester.pumpAndSettle();
    expect(find.byType(HtmlWidget), findsNothing);
    expect(find.textContaining('Welcome plain'), findsOneWidget);
  });

  testWidgets('empty-state when there is no content', (tester) async {
    await tester.pumpWidget(_host(const PptxViewer(
      file: _ref,
      slidesHtml: <PptxSlideHtml>[],
      slidesText: <PptxSlide>[],
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't read this presentation"), findsOneWidget);
  });
}
