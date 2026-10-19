import 'package:flutter/material.dart';

import '../core/file_ref.dart';
import '../core/viewer_registry.dart';
import 'directory_lister.dart';
import 'entry_visuals.dart';
import 'explorer_sort.dart';
import 'file_tap_action.dart';
import 'last_dir_store.dart';
import 'options_sheet.dart';
import 'thumbnail.dart';
import 'unsupported_modal.dart';
import 'view_mode.dart';

/// The explorer home surface. Lists one directory at a time; tapping a folder
/// navigates in (and persists the path), tapping a file routes via
/// [resolveFileTap] to either a pushed viewer or the Unsupported modal. The
/// system back button walks up one directory, or exits at [rootPath].
///
/// View/sort preferences come from [prefsStore] (persisted). Directory listing
/// is injectable ([lister]) for widget tests.
class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({
    super.key,
    required this.initialPath,
    required this.rootPath,
    required this.registry,
    required this.store,
    required this.prefsStore,
    this.lister = listDirectory,
  });

  final String initialPath;
  final String rootPath;
  final ViewerRegistry registry;
  final LastDirStore store;
  final ExplorerPrefsStore prefsStore;
  final Future<List<Entry>> Function(String path) lister;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  late String _current;
  late Future<List<Entry>> _entries;
  ExplorerPrefs _prefs = const ExplorerPrefs();

  @override
  void initState() {
    super.initState();
    _current = widget.initialPath;
    _entries = widget.lister(_current);
    widget.prefsStore.read().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  void _applyPrefs(ExplorerPrefs p) {
    setState(() => _prefs = p);
    widget.prefsStore.write(p);
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
          actions: <Widget>[
            IconButton(
              tooltip: 'View mode',
              icon: Icon(_viewModeIcon(_prefs.viewMode)),
              onPressed: _cycleViewMode,
            ),
            IconButton(
              tooltip: 'Sort & view options',
              icon: const Icon(Icons.tune),
              onPressed: _openOptions,
            ),
          ],
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
            final ordered = applyView(
              snap.data!,
              field: _prefs.sortField,
              direction: _prefs.sortDirection,
              foldersFirst: _prefs.foldersFirst,
              showHidden: _prefs.showHidden,
            );
            if (ordered.isEmpty) {
              return const Center(child: Text('Empty folder'));
            }
            return _buildBody(ordered);
          },
        ),
      ),
    );
  }

  // ---- View-mode helpers ----------------------------------------------------

  static IconData _viewModeIcon(ViewMode m) {
    switch (m) {
      case ViewMode.list:
        return Icons.view_list;
      case ViewMode.detail:
        return Icons.view_agenda_outlined;
      case ViewMode.grid:
        return Icons.grid_view;
      case ViewMode.largeGrid:
        return Icons.grid_on;
    }
  }

  void _cycleViewMode() {
    const order = ViewMode.values;
    final next = order[(order.indexOf(_prefs.viewMode) + 1) % order.length];
    _applyPrefs(_prefs.copyWith(viewMode: next));
  }

  Future<void> _openOptions() async {
    final updated = await showExplorerOptions(context, _prefs);
    if (updated != null) _applyPrefs(updated);
  }

  void _onEntryTap(Entry e) =>
      e.isDirectory ? _navigateTo(e.path) : _onFileTap(e.fileRef!);

  Widget _buildBody(List<Entry> entries) {
    switch (_prefs.viewMode) {
      case ViewMode.list:
        return _ListBody(entries: entries, onTap: _onEntryTap, detail: false);
      case ViewMode.detail:
        return _ListBody(entries: entries, onTap: _onEntryTap, detail: true);
      case ViewMode.grid:
        return _GridBody(entries: entries, onTap: _onEntryTap, columns: 3);
      case ViewMode.largeGrid:
        return _GridBody(entries: entries, onTap: _onEntryTap, columns: 2);
    }
  }
}

/// List / detail layout. In detail mode each row shows type · size · date and a
/// thumbnail; in list mode a compact icon + name + size.
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.entries,
    required this.onTap,
    required this.detail,
  });

  final List<Entry> entries;
  final void Function(Entry) onTap;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        if (!detail) {
          return ListTile(
            leading: EntryThumbnail(entry: e, size: 32),
            title: Text(e.name, overflow: TextOverflow.ellipsis),
            trailing: e.isDirectory
                ? null
                : Text(formatSize(e.size),
                    style: Theme.of(context).textTheme.bodySmall),
            onTap: () => onTap(e),
          );
        }
        final sub = e.isDirectory
            ? formatDate(e.modified)
            : <String>[
                e.fileRef!.type.name,
                formatSize(e.size),
                formatDate(e.modified),
              ].where((s) => s.isNotEmpty).join(' · ');
        return ListTile(
          leading: EntryThumbnail(entry: e, size: 44),
          title: Text(e.name, overflow: TextOverflow.ellipsis),
          subtitle: Text(sub, overflow: TextOverflow.ellipsis),
          isThreeLine: false,
          onTap: () => onTap(e),
        );
      },
    );
  }
}

/// Grid / large-grid layout: tiles with a thumbnail/icon and the name beneath.
class _GridBody extends StatelessWidget {
  const _GridBody({
    required this.entries,
    required this.onTap,
    required this.columns,
  });

  final List<Entry> entries;
  final void Function(Entry) onTap;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final tile = columns <= 2 ? 120.0 : 72.0;
        return InkWell(
          onTap: () => onTap(e),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              EntryThumbnail(entry: e, size: tile),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  e.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
