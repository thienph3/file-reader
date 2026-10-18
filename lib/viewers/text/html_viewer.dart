import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/file_ref.dart';
import '../file_loader.dart';
import '../viewer_scaffold.dart';
import 'content_format.dart';

/// HTML viewer: read-only rendered preview with a VIEW/RAW toggle.
///
/// Security (Threat Model): links are inert — `onTapUrl` returns true to mark
/// every tap "handled" so no navigation/network occurs. No scripts run
/// (the renderer does not execute JS). Oversized input shows raw only.
class HtmlViewer extends StatefulWidget {
  const HtmlViewer({super.key, required this.file, this.content});

  final FileRef file;
  final String? content;

  @override
  State<HtmlViewer> createState() => _HtmlViewerState();
}

class _HtmlViewerState extends State<HtmlViewer> {
  bool _rendered = true;
  late Future<LoadedText> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.content != null
        ? Future<LoadedText>.value(
            LoadedText(widget.content!, truncated: false))
        : loadText(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      actions: <Widget>[
        ViewerToggle(
          left: 'VIEW',
          right: 'RAW',
          leftSelected: _rendered,
          onChanged: (v) => setState(() => _rendered = v),
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
          final tooLarge = raw.length > kMaxFormatBytes;
          if (_rendered && !tooLarge) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: HtmlWidget(
                raw,
                // Mark every link tap handled -> no navigation, no network.
                onTapUrl: (_) => true,
              ),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  raw,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13, height: 1.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
