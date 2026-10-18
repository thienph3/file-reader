import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';
import 'exif_data.dart';

/// Loads EXIF entries for a file; injectable so widget tests avoid disk I/O.
typedef ExifLoader = Future<List<ExifEntry>> Function(FileRef file);

Future<List<ExifEntry>> _defaultExifLoader(FileRef file) async {
  try {
    final bytes = await File(file.path).readAsBytes();
    return readExifEntries(bytes);
  } catch (_) {
    return const <ExifEntry>[];
  }
}

/// Image viewer: pinch-zoom/pan via [InteractiveViewer], native GIF/WebP
/// animation via [Image.file], a graceful error state (covers HEIC decode
/// failure on unsupported platforms), and a toggleable EXIF metadata panel.
///
/// [imageBuilder] overrides the image widget for tests (so no real file is
/// decoded); [exifLoader] overrides EXIF loading for tests.
class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.file,
    this.exifLoader = _defaultExifLoader,
    this.imageBuilder,
  });

  final FileRef file;
  final ExifLoader exifLoader;
  final WidgetBuilder? imageBuilder;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  bool _showExif = false;
  Future<List<ExifEntry>>? _exifFuture;

  void _toggleExif() {
    setState(() {
      _showExif = !_showExif;
      _exifFuture ??= widget.exifLoader(widget.file);
    });
  }

  Widget _buildImage() {
    if (widget.imageBuilder != null) return widget.imageBuilder!(context);
    return Image.file(
      File(widget.file.path),
      errorBuilder: (context, error, stack) => const _ImageError(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      actions: <Widget>[
        IconButton(
          tooltip: 'EXIF info',
          icon: Icon(_showExif ? Icons.info : Icons.info_outline),
          onPressed: _toggleExif,
        ),
      ],
      child: Column(
        children: <Widget>[
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8,
              child: Center(child: _buildImage()),
            ),
          ),
          if (_showExif)
            SizedBox(
              height: 220,
              child: _ExifPanel(future: _exifFuture!),
            ),
        ],
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, size: 48),
          SizedBox(height: 12),
          Text("Can't display this image",
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('The format may not be supported on this device.',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ExifPanel extends StatelessWidget {
  const _ExifPanel({required this.future});
  final Future<List<ExifEntry>> future;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: FutureBuilder<List<ExifEntry>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <ExifEntry>[];
          if (entries.isEmpty) {
            return const Center(child: Text('No EXIF metadata'));
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              return ListTile(
                dense: true,
                title: Text(e.tag,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text(e.value, style: const TextStyle(fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }
}
