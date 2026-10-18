import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../file_loader.dart';
import '../viewer_scaffold.dart';

/// Plain-text / log viewer. Also handles `.md` in Phase 1 (rich Markdown is
/// Phase 5). Monospace with a wrap toggle. Content is read bounded by
/// [kMaxReadBytes]; a truncation banner shows when the file exceeds the cap.
///
/// [content] may be injected for tests; when null it is loaded from
/// [file]'s path.
class TextViewer extends StatefulWidget {
  const TextViewer({super.key, required this.file, this.content});

  final FileRef file;
  final String? content;

  @override
  State<TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<TextViewer> {
  bool _wrap = true;
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
          left: 'WRAP',
          right: 'NOWRAP',
          leftSelected: _wrap,
          onChanged: (v) => setState(() => _wrap = v),
        ),
      ],
      child: FutureBuilder<LoadedText>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorBody(message: 'Could not open file.');
          }
          final loaded = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (loaded.truncated) const _TruncatedBanner(),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: _wrap ? Axis.vertical : Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        loaded.text,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                        ),
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

class _TruncatedBanner extends StatelessWidget {
  const _TruncatedBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer,
      padding: const EdgeInsets.all(8),
      child: Text(
        'Large file — showing the first ${kMaxReadBytes ~/ (1024 * 1024)} MB.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(message, style: const TextStyle(color: Colors.red)));
}
