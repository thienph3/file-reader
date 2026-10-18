import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/viewer_registry.dart';
import 'explorer_screen.dart';
import 'last_dir_store.dart';
import 'prefs_last_dir_store.dart';

/// Abstraction over the storage-permission request, injectable for tests.
typedef RequestStorage = Future<bool> Function();

Future<bool> _defaultRequestStorage() async {
  // Narrowest-permission: request scoped read only. On Android 13+ the relevant
  // grants are the READ_MEDIA_* group; on API <=32 it is READ_EXTERNAL_STORAGE.
  // We do NOT request MANAGE_EXTERNAL_STORAGE (All-Files-Access) — a read-only
  // viewer uses scoped reads + SAF (plan.md Permissions).
  final results = await <Permission>[
    Permission.photos,
    Permission.videos,
    Permission.audio,
    Permission.storage,
  ].request();
  // Granted if any scoped read was allowed (platforms expose different subsets).
  return results.values.any((s) => s.isGranted || s.isLimited);
}

/// Resolves the storage root to list first. Uses the conventional Android
/// shared-storage path; falls back to the app's own directory elsewhere.
String defaultStorageRoot() {
  const androidRoot = '/storage/emulated/0';
  if (Platform.isAndroid && Directory(androidRoot).existsSync()) {
    return androidRoot;
  }
  return Directory.current.path;
}

/// Boots the explorer: requests permission, resolves the initial directory,
/// then shows the explorer. On denial, shows an explanatory empty-state with a
/// retry — never a blank list (see plan's Navigation & flow).
class AppBootstrap extends StatefulWidget {
  AppBootstrap({
    super.key,
    ViewerRegistry? registry,
    LastDirStore? store,
    this.requestStorage = _defaultRequestStorage,
    String? storageRoot,
  })  : registry = registry ?? _mustProvideRegistry(),
        store = store ?? PrefsLastDirStore(),
        storageRoot = storageRoot ?? defaultStorageRoot();

  final ViewerRegistry registry;
  final LastDirStore store;
  final RequestStorage requestStorage;
  final String storageRoot;

  static ViewerRegistry _mustProvideRegistry() =>
      throw ArgumentError('registry is required');

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<_BootResult> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _run();
  }

  Future<_BootResult> _run() async {
    final granted = await widget.requestStorage();
    if (!granted) return const _BootResult(granted: false, initialPath: '');
    final initial = await resolveInitialDirectory(
      storageRoot: widget.storageRoot,
      store: widget.store,
      exists: (p) => Directory(p).existsSync(),
    );
    return _BootResult(granted: true, initialPath: initial);
  }

  void _retry() => setState(() => _boot = _run());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootResult>(
      future: _boot,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final result = snap.data!;
        if (!result.granted) {
          return _PermissionDenied(onRetry: _retry);
        }
        return ExplorerScreen(
          initialPath: result.initialPath,
          rootPath: widget.storageRoot,
          registry: widget.registry,
          store: widget.store,
        );
      },
    );
  }
}

class _BootResult {
  const _BootResult({required this.granted, required this.initialPath});
  final bool granted;
  final String initialPath;
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Reader')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Access not granted',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Grant storage access to browse your files. You can enable it '
                'here or in system settings.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: onRetry, child: const Text('Grant access')),
              TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open settings')),
            ],
          ),
        ),
      ),
    );
  }
}
