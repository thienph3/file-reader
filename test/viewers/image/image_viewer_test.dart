import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/image/exif_data.dart';
import 'package:file_reader/viewers/image/image_viewer.dart';
import 'package:file_reader/viewers/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ref = FileRef(
  path: '/x/photo.jpg',
  name: 'photo.jpg',
  type: FileType.image,
);

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows the image viewer scaffold with an EXIF toggle',
      (tester) async {
    await tester.pumpWidget(_host(ImageViewer(
      file: _ref,
      imageBuilder: (_) => const SizedBox(key: Key('img'), width: 10, height: 10),
      exifLoader: (_) async => const <ExifEntry>[],
    )));
    await tester.pumpAndSettle();
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(const Key('img')), findsOneWidget);
    expect(find.byTooltip('EXIF info'), findsOneWidget);
  });

  testWidgets('EXIF toggle opens the panel and lists injected entries',
      (tester) async {
    await tester.pumpWidget(_host(ImageViewer(
      file: _ref,
      imageBuilder: (_) => const SizedBox(),
      exifLoader: (_) async => const <ExifEntry>[
        ExifEntry('Image Make', 'Acme'),
        ExifEntry('Image Model', 'Cam 1'),
      ],
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('EXIF info'));
    await tester.pumpAndSettle();
    expect(find.text('Image Make'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Image Model'), findsOneWidget);
  });

  testWidgets('EXIF panel shows a no-metadata message when empty',
      (tester) async {
    await tester.pumpWidget(_host(ImageViewer(
      file: _ref,
      imageBuilder: (_) => const SizedBox(),
      exifLoader: (_) async => const <ExifEntry>[],
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('EXIF info'));
    await tester.pumpAndSettle();
    expect(find.text('No EXIF metadata'), findsOneWidget);
  });

  test('registry resolves the image type to a viewer', () {
    final r = buildPhase1Registry();
    expect(r.isSupported(FileType.image), isTrue);
    expect(r.resolve(FileType.image), isNotNull);
  });
}
