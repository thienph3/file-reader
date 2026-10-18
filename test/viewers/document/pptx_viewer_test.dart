import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/document/pptx_extract.dart';
import 'package:file_reader/viewers/document/pptx_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ref =
    FileRef(path: '/x/deck.pptx', name: 'deck.pptx', type: FileType.pptx);

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('PptxViewer shows per-slide headers and text', (tester) async {
    await tester.pumpWidget(_host(PptxViewer(
      file: _ref,
      slides: const <PptxSlide>[
        PptxSlide(index: 1, texts: <String>['Welcome', 'Agenda']),
        PptxSlide(index: 2, texts: <String>['Topic one']),
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.text('deck.pptx'), findsOneWidget);
    expect(find.text('Slide 1'), findsOneWidget);
    expect(find.text('Slide 2'), findsOneWidget);
    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(find.textContaining('Topic one'), findsOneWidget);
  });

  testWidgets('PptxViewer shows an empty-state when there are no slides',
      (tester) async {
    await tester.pumpWidget(_host(const PptxViewer(
      file: _ref,
      slides: <PptxSlide>[],
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't read this presentation"), findsOneWidget);
  });

  testWidgets('PptxViewer marks a text-less slide as (no text)',
      (tester) async {
    await tester.pumpWidget(_host(PptxViewer(
      file: _ref,
      slides: const <PptxSlide>[PptxSlide(index: 1, texts: <String>[])],
    )));
    await tester.pumpAndSettle();
    expect(find.text('(no text)'), findsOneWidget);
  });
}
