import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_reader/viewers/archive/zip_entries.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, c) {
    final b = c.codeUnits;
    a.addFile(ArchiveFile(n, b.length, b));
  });
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

void main() {
  group('listZipEntries', () {
    test('lists safe file entries, sorted', () {
      final z = _zip(<String, String>{
        'notes.txt': 'hello',
        'sub/data.json': '{}',
      });
      final names = listZipEntries(z).map((e) => e.name).toList();
      expect(names, <String>['notes.txt', 'sub/data.json']);
    });

    test('excludes parent-traversal and absolute-path entries', () {
      final z = _zip(<String, String>{
        'ok.txt': 'x',
        '../evil.txt': 'bad',
        '/abs.txt': 'bad',
        'a/../../b.txt': 'bad',
      });
      final names = listZipEntries(z).map((e) => e.name).toList();
      expect(names, <String>['ok.txt']);
    });

    test('malformed (non-zip) bytes -> empty, no throw', () {
      expect(listZipEntries(List<int>.filled(64, 9)), isEmpty);
    });

    test('oversized archive -> empty (capped)', () {
      final z = _zip(<String, String>{'a.txt': 'x'});
      expect(listZipEntries(z, maxBytes: 4), isEmpty);
    });
  });

  group('readZipEntry', () {
    test('returns bytes for a safe entry', () {
      final z = _zip(<String, String>{'notes.txt': 'hello world'});
      final bytes = readZipEntry(z, 'notes.txt');
      expect(bytes, isNotNull);
      expect(String.fromCharCodes(bytes!), 'hello world');
    });

    test('returns null for a traversal name', () {
      final z = _zip(<String, String>{'../evil.txt': 'bad'});
      expect(readZipEntry(z, '../evil.txt'), isNull);
    });

    test('returns null for a missing name', () {
      final z = _zip(<String, String>{'a.txt': 'x'});
      expect(readZipEntry(z, 'nope.txt'), isNull);
    });

    test('returns null when the entry exceeds the per-entry cap', () {
      final z = _zip(<String, String>{'big.txt': 'x' * 1000});
      expect(readZipEntry(z, 'big.txt', maxEntryBytes: 10), isNull);
    });

    test('malformed bytes -> null, no throw', () {
      expect(readZipEntry(List<int>.filled(64, 9), 'a.txt'), isNull);
    });
  });
}
