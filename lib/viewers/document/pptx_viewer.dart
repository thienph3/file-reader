import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
import '../viewer_scaffold.dart';
import 'pptx_extract.dart';
import 'pptx_html.dart';

/// `.pptx` viewer: a per-slide outline. **Formatted** mode renders each slide's
/// styled text (colour, bold/italic/underline, size) and inline images via
/// `flutter_widget_from_html_core`; **Plain** mode shows each slide's text.
/// Content per slide — not positioned-canvas slide rendering (no local engine).
///
/// [slidesHtml] / [slidesText] may be injected for tests.
class PptxViewer extends StatefulWidget {
  const PptxViewer({
    super.key,
    required this.file,
    this.slidesHtml,
    this.slidesText,
  });

  final FileRef file;
  final List<PptxSlideHtml>? slidesHtml;
  final List<PptxSlide>? slidesText;

  @override
  State<PptxViewer> createState() => _PptxViewerState();
}

class _PptxContent {
  const _PptxContent(this.html, this.text);
  final List<PptxSlideHtml> html;
  final List<PptxSlide> text;
}

class _PptxViewerState extends State<PptxViewer> {
  bool _formatted = true;
  late Future<_PptxContent> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.slidesHtml != null || widget.slidesText != null)
        ? Future<_PptxContent>.value(_PptxContent(
            widget.slidesHtml ?? const <PptxSlideHtml>[],
            widget.slidesText ?? const <PptxSlide>[]))
        : _load();
  }

  Future<_PptxContent> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return _PptxContent(pptxToHtmlSlides(bytes), extractPptxSlides(bytes));
    } catch (_) {
      return const _PptxContent(<PptxSlideHtml>[], <PptxSlide>[]);
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
      child: FutureBuilder<_PptxContent>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const ViewerLoading();
          }
          final content = snap.data!;
          final hasHtml =
              content.html.any((s) => s.html.trim().isNotEmpty);
          final hasText = content.text.isNotEmpty;
          if (!hasHtml && !hasText) {
            return const ViewerEmpty(
              icon: Icons.slideshow_outlined,
              title: "Can't read this presentation",
              hint: 'It may be empty or use an unsupported structure.',
            );
          }
          final showFormatted = _formatted && hasHtml;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ExtractionBadge(
                  label: 'Slide content — not positioned slide layout'),
              Expanded(
                child: showFormatted
                    ? _FormattedSlides(slides: content.html)
                    : _PlainSlides(slides: content.text),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FormattedSlides extends StatelessWidget {
  const _FormattedSlides({required this.slides});
  final List<PptxSlideHtml> slides;

  @override
  Widget build(BuildContext context) {
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
            if (s.html.trim().isEmpty)
              Text('(no content)',
                  style: TextStyle(
                      color: Theme.of(context).disabledColor,
                      fontStyle: FontStyle.italic))
            else
              HtmlWidget(s.html, onTapUrl: (_) => true),
          ],
        );
      },
    );
  }
}

class _PlainSlides extends StatelessWidget {
  const _PlainSlides({required this.slides});
  final List<PptxSlide> slides;

  @override
  Widget build(BuildContext context) {
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
  }
}
