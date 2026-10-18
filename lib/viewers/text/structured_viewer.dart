import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../../core/file_type.dart';
import '../file_loader.dart';
import '../viewer_scaffold.dart';
import 'content_format.dart';

/// JSON / XML viewer: pretty-prints structured text with a VIEW/RAW toggle.
/// Malformed or oversized input falls back to raw automatically (see
/// [formatJson] / [formatXml]); XML never dereferences external entities.
class StructuredViewer extends StatefulWidget {
  const StructuredViewer({super.key, required this.file, this.content});

  final FileRef file;
  final String? content;

  @override
  State<StructuredViewer> createState() => _StructuredViewerState();
}

class _StructuredViewerState extends State<StructuredViewer> {
  bool _pretty = true;
  late Future<LoadedText> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.content != null
        ? Future<LoadedText>.value(
            LoadedText(widget.content!, truncated: false))
        : loadText(widget.file.path);
  }

  FormatResult _format(String raw) =>
      widget.file.type == FileType.xml ? formatXml(raw) : formatJson(raw);

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      actions: <Widget>[
        ViewerToggle(
          left: 'VIEW',
          right: 'RAW',
          leftSelected: _pretty,
          onChanged: (v) => setState(() => _pretty = v),
        ),
      ],
      child: FutureBuilder<LoadedText>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Could not open file.',
                  style: TextStyle(color: Colors.red)),
            );
          }
          final raw = snap.data!.text;
          final formatted = _format(raw);
          // When formatting failed, the VIEW tab shows raw too (with a note).
          final showPretty = _pretty && formatted.ok;
          final body = showPretty ? formatted.text! : raw;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_pretty && !formatted.ok)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text("Couldn't parse — showing raw text.",
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        body,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13, height: 1.5),
                      ),
                    ),
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
