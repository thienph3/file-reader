import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../../core/file_type.dart';
import '../../explorer/unsupported_modal.dart';
import '../text/csv_viewer.dart';
import '../text/html_viewer.dart';
import '../text/structured_viewer.dart';
import '../text/text_viewer.dart';
import '../viewer_scaffold.dart';
import 'zip_entries.dart';

/// Reads the whole archive bytes for a path (injectable for tests).
typedef ArchiveBytesLoader = Future<List<int>> Function(String path);

Future<List<int>> _defaultBytesLoader(String path) => File(path).readAsBytes();

/// Browses a `.zip`: lists safe entries and previews a tapped **text-family**
/// inner file in memory (no disk writes — see phase4/decisions.md). Non-text
/// inner files show the Unsupported-file modal.
class ArchiveBrowser extends StatefulWidget {
  const ArchiveBrowser({
    super.key,
    required this.file,
    this.bytesLoader = _defaultBytesLoader,
  });

  final FileRef file;
  final ArchiveBytesLoader bytesLoader;

  @override
  State<ArchiveBrowser> createState() => _ArchiveBrowserState();
}

class _ArchiveBrowserState extends State<ArchiveBrowser> {
  late Future<_Loaded> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Loaded> _load() async {
    try {
      final bytes = await widget.bytesLoader(widget.file.path);
      return _Loaded(bytes, listZipEntries(bytes));
    } catch (_) {
      return _Loaded(const <int>[], const <ZipEntry>[]);
    }
  }

  /// Text-family types we can preview from in-memory bytes.
  static const Set<FileType> _textFamily = <FileType>{
    FileType.plainText,
    FileType.markdown,
    FileType.json,
    FileType.xml,
    FileType.csv,
    FileType.html,
  };

  Widget? _textViewerFor(FileRef ref, String content) {
    switch (ref.type) {
      case FileType.plainText:
      case FileType.markdown:
        return TextViewer(file: ref, content: content);
      case FileType.json:
      case FileType.xml:
        return StructuredViewer(file: ref, content: content);
      case FileType.csv:
        return CsvViewer(file: ref, content: content);
      case FileType.html:
        return HtmlViewer(file: ref, content: content);
      default:
        return null;
    }
  }

  Future<void> _openEntry(List<int> archiveBytes, ZipEntry entry) async {
    final type = detectFileType(entry.name);
    final isText = _textFamily.contains(type);
    final isImage = type == FileType.image;
    if (!isText && !isImage) {
      await showUnsupportedModal(context, entry.name);
      return;
    }
    final bytes = readZipEntry(archiveBytes, entry.name);
    if (bytes == null) {
      if (mounted) await showUnsupportedModal(context, entry.name);
      return;
    }
    final innerName = entry.name.split('/').last;
    if (isImage) {
      // CBZ / zipped images: preview in-memory, no disk write.
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _InnerImagePage(name: innerName, bytes: bytes),
        ),
      );
      return;
    }
    final content = utf8.decode(bytes, allowMalformed: true);
    final innerRef = FileRef(
      path: '${widget.file.path}!/${entry.name}',
      name: innerName,
      type: type,
      size: entry.size,
    );
    final viewer = _textViewerFor(innerRef, content);
    if (viewer == null) {
      if (mounted) await showUnsupportedModal(context, entry.name);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => viewer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: FutureBuilder<_Loaded>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final loaded = snap.data!;
          if (loaded.entries.isEmpty) {
            return const Center(
                child: Text('Empty or unreadable archive.'));
          }
          return ListView.separated(
            itemCount: loaded.entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = loaded.entries[i];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(e.name),
                subtitle: Text('${e.size} bytes'),
                onTap: () => _openEntry(loaded.bytes, e),
              );
            },
          );
        },
      ),
    );
  }
}

class _Loaded {
  const _Loaded(this.bytes, this.entries);
  final List<int> bytes;
  final List<ZipEntry> entries;
}

/// In-memory preview of an image entry inside a zip/cbz. Bytes come from
/// [readZipEntry] (size-capped); nothing is written to disk.
class _InnerImagePage extends StatelessWidget {
  const _InnerImagePage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: name,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 8,
        child: Center(
          child: Image.memory(
            bytes,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text("Can't display this image"),
            ),
          ),
        ),
      ),
    );
  }
}
