import 'dart:io';

import 'package:file_reader/explorer/app_bootstrap.dart';
import 'package:file_reader/explorer/last_dir_store.dart';
import 'package:file_reader/explorer/view_mode.dart';
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

class _FakePrefsStore implements ExplorerPrefsStore {
  ExplorerPrefs value = const ExplorerPrefs();
  @override
  Future<ExplorerPrefs> read() async => value;
  @override
  Future<void> write(ExplorerPrefs p) async => value = p;
}

void main() {
  // Locks the graceful-degradation contract for the All-Files-Access change:
  // if the user declines the permission, the app shows an explanatory state
  // with a retry — never a crash or a blank screen. (The granted path is
  // covered by the explorer widget tests with an injected directory lister.)
  testWidgets('permission denied -> explanatory state with retry, not a crash',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppBootstrap(
        registry: buildPhase1Registry(),
        store: _MemStore(),
        prefsStore: _FakePrefsStore(),
        storageRoot: Directory.systemTemp.path,
        requestStorage: () async => false, // user declined
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Access not granted'), findsOneWidget);
    expect(find.text('Grant access'), findsOneWidget); // retry affordance
  });
}
