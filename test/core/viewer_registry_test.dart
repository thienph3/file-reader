import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/core/viewer_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ViewerRegistry buildRegistry() => ViewerRegistry(<FileType, ViewerBuilder>{
        FileType.plainText: (_) => const SizedBox(),
        FileType.markdown: (_) => const SizedBox(),
        FileType.json: (_) => const SizedBox(),
        FileType.xml: (_) => const SizedBox(),
        FileType.csv: (_) => const SizedBox(),
        FileType.html: (_) => const SizedBox(),
      });

  group('ViewerRegistry', () {
    test('resolves a registered type to a non-null builder', () {
      final r = buildRegistry();
      expect(r.resolve(FileType.csv), isNotNull);
      expect(r.isSupported(FileType.csv), isTrue);
    });

    test('markdown is supported (routed to the text viewer in Phase 1)', () {
      final r = buildRegistry();
      expect(r.isSupported(FileType.markdown), isTrue);
      expect(r.resolve(FileType.markdown), isNotNull);
    });

    test('unsupported type returns null and is not supported', () {
      final r = buildRegistry();
      expect(r.resolve(FileType.unsupported), isNull);
      expect(r.isSupported(FileType.unsupported), isFalse);
    });

    test('a type with no registered builder is not supported', () {
      final r = ViewerRegistry(<FileType, ViewerBuilder>{
        FileType.plainText: (_) => const SizedBox(),
      });
      expect(r.resolve(FileType.csv), isNull);
      expect(r.isSupported(FileType.csv), isFalse);
      expect(r.isSupported(FileType.plainText), isTrue);
    });

    test('resolved builder produces a widget for a FileRef', () {
      final r = buildRegistry();
      final builder = r.resolve(FileType.plainText)!;
      const ref = FileRef(
        path: '/x/notes.txt',
        name: 'notes.txt',
        type: FileType.plainText,
      );
      expect(builder(ref), isA<Widget>());
    });
  });
}
