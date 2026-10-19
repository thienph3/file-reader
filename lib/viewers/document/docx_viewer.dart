import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
import '../viewer_scaffold.dart';
import 'docx_html.dart';
import 'office_extract.dart';

/// `.docx` viewer: renders **structured content** — headings, bold/italic/
/// underline, lists, tables, and inline images — parsed from the document XML
/// and shown via `flutter_widget_from_html_core`. A Formatted ↔ Plain toggle
/// falls back to extracted plain text. Structural fidelity, not pixel-perfect
/// page layout (no local office renderer exists — see plan). Read-only.
///
/// [html] / [text] may be injected for tests; otherwise the file is read and
/// both forms are derived from its bytes.
class DocxViewer extends StatefulWidget {
  const DocxViewer({super.key, required this.file, this.html, this.text});

  final FileRef file;
  final String? html;
  final String? text;

  @override
  State<DocxViewer> createState() => _DocxViewerState();
}

class _DocxContent {
  const _DocxContent(this.html, this.text);
  final String html;
  final String text;
}

class _DocxViewerState extends State<DocxViewer> {
  bool _formatted = true;
  late Future<_DocxContent> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.html != null || widget.text != null)
        ? Future<_DocxContent>.value(
            _DocxContent(widget.html ?? '', widget.text ?? ''))
        : _load();
  }

  Future<_DocxContent> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return _DocxContent(docxToHtml(bytes), extractDocxText(bytes));
    } catch (_) {
      return const _DocxContent('', '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      actions: <Widget>[
        ViewerToggle(
          left: 'FORMATTED',
          right: 'PLAIN',
          leftSelected: _formatted,
          onChanged: (v) => setState(() => _formatted = v),
        ),
      ],
      child: FutureBuilder<_DocxContent>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const ViewerLoading();
          }
          final content = snap.data!;
          final hasHtml = content.html.trim().isNotEmpty;
          final hasText = content.text.trim().isNotEmpty;
          if (!hasHtml && !hasText) {
            return const ViewerEmpty(
              icon: Icons.description_outlined,
              title: 'No readable content',
              hint: 'This document may be empty or use unsupported content.',
            );
          }
          // If formatting is unavailable, show plain text regardless of toggle.
          final showFormatted = _formatted && hasHtml;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ExtractionBadge(
                  label: 'Formatting & images shown; exact page layout may differ'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: showFormatted
                      ? HtmlWidget(
                          content.html,
                          onTapUrl: (_) => true, // links inert
                        )
                      : SelectableText(
                          hasText ? content.text : '(no text)',
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
