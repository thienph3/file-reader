import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/viewers/archive/archive_browser.dart';
import 'package:file_reader/viewers/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, c) {
    final b = c.codeUnits;
    a.addFile(ArchiveFile(n, b.length, b));
  });
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

Uint8List _zipBytes(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((n, b) => a.addFile(ArchiveFile(n, b.length, b)));
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

const _ref = FileRef(
  path: '/x/bundle.zip',
  name: 'bundle.zip',
  type: FileType.archive,
);

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('lists safe entries from the archive', (tester) async {
    final zip = _zip(<String, String>{
      'readme.txt': 'hello inside zip',
      'data.json': '{"a":1}',
      '../evil.txt': 'bad',
    });
    await tester.pumpWidget(_host(ArchiveBrowser(
      file: _ref,
      bytesLoader: (_) async => zip,
    )));
    await tester.pumpAndSettle();
    expect(find.text('readme.txt'), findsOneWidget);
    expect(find.text('data.json'), findsOneWidget);
    // Traversal entry must not be listed.
    expect(find.text('../evil.txt'), findsNothing);
  });

  testWidgets('tapping a text inner file opens a text viewer with its content',
      (tester) async {
    final zip = _zip(<String, String>{'readme.txt': 'hello inside zip'});
    await tester.pumpWidget(_host(ArchiveBrowser(
      file: _ref,
      bytesLoader: (_) async => zip,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('readme.txt'));
    await tester.pumpAndSettle();
    // Inner text viewer shows the decoded content (with the shared overflow menu).
    expect(find.textContaining('hello inside zip'), findsOneWidget);
    expect(find.byTooltip('Options'), findsOneWidget);
  });

  testWidgets('tapping a non-previewable inner file shows the unsupported modal',
      (tester) async {
    // .pdf inner file: not text-family, not image → modal (no in-archive viewer).
    final zip = _zip(<String, String>{'doc.pdf': '%PDF-1.4 fake'});
    await tester.pumpWidget(_host(ArchiveBrowser(
      file: _ref,
      bytesLoader: (_) async => zip,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('doc.pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't open this file"), findsOneWidget);
  });

  testWidgets('tapping an image inner file opens an in-memory image preview',
      (tester) async {
    // A 1x1 PNG so Image.memory has valid bytes to decode in the test.
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    final png = base64Decode(pngBase64);
    final zip = _zipBytes(<String, List<int>>{'page1.png': png});
    await tester.pumpWidget(_host(ArchiveBrowser(
      file: _ref,
      bytesLoader: (_) async => zip,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('page1.png'));
    await tester.pumpAndSettle();
    // Opened an image preview (not the unsupported modal).
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining("Can't open this file"), findsNothing);
  });

  test('registry resolves audio/video/archive', () {
    final r = buildPhase1Registry();
    expect(r.isSupported(FileType.audio), isTrue);
    expect(r.isSupported(FileType.video), isTrue);
    expect(r.isSupported(FileType.archive), isTrue);
    expect(r.resolve(FileType.audio), isNotNull);
    expect(r.resolve(FileType.video), isNotNull);
    expect(r.resolve(FileType.archive), isNotNull);
  });
}
