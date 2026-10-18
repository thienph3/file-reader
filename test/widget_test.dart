import 'package:file_reader/core/file_ref.dart';
import 'package:file_reader/core/file_type.dart';
import 'package:file_reader/core/viewer_registry.dart';
import 'package:file_reader/explorer/directory_lister.dart';
import 'package:file_reader/explorer/explorer_screen.dart';
import 'package:file_reader/explorer/last_dir_store.dart';
import 'package:file_reader/viewers/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemStore implements LastDirStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String path) async => value = path;
}

/// A registry whose viewers do no file I/O, so navigation tests don't hit disk.
ViewerRegistry testRegistry() => ViewerRegistry(<FileType, ViewerBuilder>{
      FileType.plainText: (f) => Scaffold(
            appBar: AppBar(title: Text(f.name)),
            body: const Center(child: Text('VIEWER-STUB')),
          ),
    });

void main() {
  const root = '/root';

  // Fake filesystem: /root has a folder "Docs" and files; /root/Docs has one txt.
  Future<List<Entry>> fakeLister(String path) async {
    if (path == root) {
      return <Entry>[
        const Entry.directory('Docs', '$root/Docs'),
        Entry.file(const FileRef(
            path: '$root/a.txt', name: 'a.txt', type: FileType.plainText)),
        Entry.file(const FileRef(
            path: '$root/x.zip', name: 'x.zip', type: FileType.unsupported)),
      ];
    }
    if (path == '$root/Docs') {
      return <Entry>[
        Entry.file(const FileRef(
            path: '$root/Docs/n.txt',
            name: 'n.txt',
            type: FileType.plainText)),
      ];
    }
    return <Entry>[];
  }

  Widget host(LastDirStore store, {ViewerRegistry? registry}) => MaterialApp(
        home: ExplorerScreen(
          initialPath: root,
          rootPath: root,
          registry: registry ?? buildPhase1Registry(),
          store: store,
          lister: fakeLister,
        ),
      );

  testWidgets('lists folders and files at the root', (tester) async {
    await tester.pumpWidget(host(_MemStore()));
    await tester.pumpAndSettle();
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('x.zip'), findsOneWidget);
  });

  testWidgets('tapping a folder navigates in and persists the path',
      (tester) async {
    final store = _MemStore();
    await tester.pumpWidget(host(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    expect(find.text('n.txt'), findsOneWidget);
    expect(store.value, '$root/Docs');
  });

  testWidgets('tapping a supported file pushes a viewer; back returns',
      (tester) async {
    await tester.pumpWidget(host(_MemStore(), registry: testRegistry()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a.txt'));
    await tester.pumpAndSettle();
    // The pushed viewer is on top.
    expect(find.text('VIEWER-STUB'), findsOneWidget);
    // Back to explorer.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Docs'), findsOneWidget);
  });

  testWidgets('tapping an unsupported file shows the modal, no navigation',
      (tester) async {
    await tester.pumpWidget(host(_MemStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('x.zip'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Can't open this file"), findsOneWidget);
    // Still in the explorer behind the sheet.
    expect(find.text('Docs'), findsOneWidget);
  });
}
