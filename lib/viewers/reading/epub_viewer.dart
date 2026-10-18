import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';
import 'epub_book.dart';

/// EPUB reader: parses the book into chapters and renders each chapter's HTML
/// (via the existing `flutter_widget_from_html_core`), with prev/next chapter
/// navigation. Links are inert (`onTapUrl => true`), as in the HTML viewer.
///
/// [chapters] may be injected for tests; otherwise the file is read + parsed.
class EpubViewer extends StatefulWidget {
  const EpubViewer({super.key, required this.file, this.chapters});

  final FileRef file;
  final List<EpubChapterText>? chapters;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  late Future<List<EpubChapterText>> _future;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.chapters != null
        ? Future<List<EpubChapterText>>.value(widget.chapters!)
        : _load();
  }

  Future<List<EpubChapterText>> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return parseEpub(bytes);
    } catch (_) {
      return const <EpubChapterText>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: FutureBuilder<List<EpubChapterText>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final chapters = snap.data ?? const <EpubChapterText>[];
          if (chapters.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text("Can't read this e-book — it may be empty or use "
                    'an unsupported structure.'),
              ),
            );
          }
          final i = _index.clamp(0, chapters.length - 1);
          final chapter = chapters[i];
          return Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: HtmlWidget(
                    chapter.html,
                    onTapUrl: (_) => true, // inert links (no nav/network)
                  ),
                ),
              ),
              _ChapterNav(
                index: i,
                count: chapters.length,
                title: chapter.title,
                onPrev: i > 0 ? () => setState(() => _index = i - 1) : null,
                onNext: i < chapters.length - 1
                    ? () => setState(() => _index = i + 1)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterNav extends StatelessWidget {
  const _ChapterNav({
    required this.index,
    required this.count,
    required this.title,
    required this.onPrev,
    required this.onNext,
  });

  final int index;
  final int count;
  final String title;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              title.isEmpty ? 'Chapter ${index + 1} of $count' : title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
