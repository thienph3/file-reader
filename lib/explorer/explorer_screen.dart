import 'package:flutter/material.dart';

import '../core/file_ref.dart';
import '../core/viewer_registry.dart';
import 'directory_lister.dart';
import 'file_tap_action.dart';
import 'last_dir_store.dart';
import 'unsupported_modal.dart';

/// The explorer home surface. Lists one directory at a time; tapping a folder
/// navigates in (and persists the path), tapping a file routes via
/// [resolveFileTap] to either a pushed viewer or the Unsupported modal. The
/// system back button walks up one directory, or exits at [rootPath].
///
/// Directory listing is injectable ([lister]) for widget tests.
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({
    super.key,
    required this.initialPath,
    required this.rootPath,
    required this.registry,
    required this.store,
    this.lister = listDirectory,
  });

  final String initialPath;
  final String rootPath;
  final ViewerRegistry registry;
  final LastDirStore store;
  final Future<List<Entry>> Function(String path) lister;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  late String _current;
  late Future<List<Entry>> _entries;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPath;
    _entries = widget.lister(_current);
  }

  void _navigateTo(String path) {
    setState(() {
      _current = path;
      _entries = widget.lister(path);
    });
    widget.store.write(path);
  }

  bool get _atRoot {
    if (_current == widget.rootPath) return true;
    // Treat anything not strictly *under* root (root + separator) as root, so a
    // sibling path like "<root>extra" is not mistaken for a descendant.
    final rootWithSep = widget.rootPath.endsWith('/')
        ? widget.rootPath
        : '${widget.rootPath}/';
    return !_current.startsWith(rootWithSep);
  }

  void _goUp() {
    if (_atRoot) return;
    final parent = _current.substring(0, _current.lastIndexOf('/'));
    _navigateTo(parent.isEmpty ? widget.rootPath : parent);
  }

  Future<void> _onFileTap(FileRef ref) async {
    final action = resolveFileTap(ref, widget.registry);
    switch (action) {
      case OpenViewer(:final file):
        final builder = widget.registry.resolve(file.type)!;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => builder(file)),
        );
      case ShowUnsupported(:final fileName):
        if (!mounted) return;
        await showUnsupportedModal(context, fileName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _atRoot
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goUp,
                ),
          title: Text(
            _atRoot ? 'Files' : _current.split('/').last,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _current,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<Entry>>(
          future: _entries,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const Center(child: Text('Could not read this folder.'));
            }
            final entries = snap.data!;
            if (entries.isEmpty) {
              return const Center(child: Text('Empty folder'));
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: Icon(
                      e.isDirectory ? Icons.folder : Icons.insert_drive_file),
                  title: Text(e.name),
                  onTap: () => e.isDirectory
                      ? _navigateTo(e.path)
                      : _onFileTap(e.fileRef!),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
