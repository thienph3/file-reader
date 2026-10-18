import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';
import 'pptx_extract.dart';

/// `.pptx` viewer: shows the **text** of each slide (content, not layout — no
/// local slide renderer exists; see phase6/decisions.md). A scrollable outline
/// with a "Slide N" header per slide.
///
/// [slides] may be injected for tests; otherwise the file is read + extracted.
class PptxViewer extends StatefulWidget {
  const PptxViewer({super.key, required this.file, this.slides});

  final FileRef file;
  final List<PptxSlide>? slides;

  @override
  State<PptxViewer> createState() => _PptxViewerState();
}

class _PptxViewerState extends State<PptxViewer> {
  late Future<List<PptxSlide>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.slides != null
        ? Future<List<PptxSlide>>.value(widget.slides!)
        : _load();
  }

  Future<List<PptxSlide>> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return extractPptxSlides(bytes);
    } catch (_) {
      return const <PptxSlide>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: FutureBuilder<List<PptxSlide>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final slides = snap.data ?? const <PptxSlide>[];
          if (slides.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text("Can't read this presentation — it may be empty "
                    'or use an unsupported structure.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: slides.length,
            separatorBuilder: (_, _) => const Divider(height: 32),
            itemBuilder: (context, i) {
              final s = slides[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Slide ${s.index}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (s.texts.isEmpty)
                    Text('(no text)',
                        style: TextStyle(
                            color: Theme.of(context).disabledColor,
                            fontStyle: FontStyle.italic))
                  else
                    SelectableText(s.texts.join('\n'),
                        style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
