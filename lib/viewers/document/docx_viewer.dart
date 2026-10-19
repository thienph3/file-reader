import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
import '../viewer_scaffold.dart';
import 'office_extract.dart';

/// `.docx` viewer: shows extracted plain text (content, not layout).
///
/// [text] may be injected for tests; otherwise the file is read and extracted.
class DocxViewer extends StatefulWidget {
  const DocxViewer({super.key, required this.file, this.text});

  final FileRef file;
  final String? text;

  @override
  State<DocxViewer> createState() => _DocxViewerState();
}

class _DocxViewerState extends State<DocxViewer> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.text != null
        ? Future<String>.value(widget.text!)
        : _load();
  }

  Future<String> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return extractDocxText(bytes);
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
            return const ViewerLoading();
          }
          final text = snap.data ?? '';
          if (text.trim().isEmpty) {
            return const ViewerEmpty(
              icon: Icons.description_outlined,
              title: 'No readable text',
              hint: 'This document may be empty or use unsupported content.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ExtractionBadge(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(text,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
