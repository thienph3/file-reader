import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';
import 'rtf_to_text.dart';

/// `.rtf` viewer: extracts best-effort plain text (content, not layout) and
/// shows it. [content] may be injected for tests; otherwise the file is read
/// and converted. Extraction never throws (see [rtfToText]).
class RtfViewer extends StatefulWidget {
  const RtfViewer({super.key, required this.file, this.content});

  final FileRef file;
  final String? content;

  @override
  State<RtfViewer> createState() => _RtfViewerState();
}

class _RtfViewerState extends State<RtfViewer> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.content != null
        ? Future<String>.value(rtfToText(widget.content!))
        : _load();
  }

  Future<String> _load() async {
    try {
      final raw = await File(widget.file.path)
          .readAsString(encoding: const Utf8Codec(allowMalformed: true));
      return rtfToText(raw);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: FutureBuilder<String>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = snap.data ?? '';
          if (text.trim().isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No readable text in this document.'),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(text,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          );
        },
      ),
    );
  }
}
