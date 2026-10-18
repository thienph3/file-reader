import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/core/viewer_registry.dart';
import 'package:file_reader/explorer/file_tap_action.dart';
import 'package:file_reader/explorer/last_dir_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [LastDirStore] for tests.
class _MemStore implements LastDirStore {
  _MemStore([this.value]);
  String? value;
  final List<String> writes = <String>[];

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String path) async {
    value = path;
    writes.add(path);
  }
}

void main() {
  const root = '/storage/emulated/0';

  ViewerRegistry registry() => ViewerRegistry(<FileType, ViewerBuilder>{
        FileType.plainText: (_) => const SizedBox(),
        FileType.markdown: (_) => const SizedBox(),
        FileType.json: (_) => const SizedBox(),
        FileType.xml: (_) => const SizedBox(),
        FileType.csv: (_) => const SizedBox(),
        FileType.html: (_) => const SizedBox(),
      });

  group('resolveInitialDirectory', () {
    test('first launch (no persisted path) -> storage root', () async {
      final store = _MemStore();
      final dir = await resolveInitialDirectory(
        storageRoot: root,
        store: store,
        exists: (_) => true,
      );
      expect(dir, root);
    });

    test('returning launch with a valid last-viewed path -> that path',
        () async {
      final store = _MemStore('$root/Documents');
      final dir = await resolveInitialDirectory(
        storageRoot: root,
        store: store,
        exists: (_) => true,
      );
      expect(dir, '$root/Documents');
    });

    test('stale last-viewed path -> root, and self-heals the stored value',
        () async {
      final store = _MemStore('$root/Removed');
      final dir = await resolveInitialDirectory(
        storageRoot: root,
        store: store,
        exists: (path) => path != '$root/Removed',
      );
      expect(dir, root);
      expect(store.value, root, reason: 'stale value overwritten with root');
    });

    test('empty persisted string is treated as first launch', () async {
      final store = _MemStore('');
      final dir = await resolveInitialDirectory(
        storageRoot: root,
        store: store,
        exists: (_) => true,
      );
      expect(dir, root);
    });
  });

  group('resolveFileTap', () {
    test('supported file -> OpenViewer with the same ref', () {
      const ref = FileRef(
        path: '$root/notes.txt',
        name: 'notes.txt',
        type: FileType.plainText,
      );
      expect(resolveFileTap(ref, registry()), const OpenViewer(ref));
    });

    test('markdown file -> OpenViewer (routed to text viewer in Phase 1)', () {
      const ref = FileRef(
        path: '$root/README.md',
        name: 'README.md',
        type: FileType.markdown,
      );
      expect(resolveFileTap(ref, registry()), const OpenViewer(ref));
    });

    test('unsupported file -> ShowUnsupported, no viewer', () {
      const ref = FileRef(
        path: '$root/archive.zip',
        name: 'archive.zip',
        type: FileType.unsupported,
      );
      expect(
        resolveFileTap(ref, registry()),
        const ShowUnsupported(
            fileName: 'archive.zip', type: FileType.unsupported),
      );
    });
  });
}
