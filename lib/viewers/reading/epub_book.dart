import 'package:epubx/epubx.dart';

/// A flattened EPUB chapter: title + HTML content, ready to render.
class EpubChapterText {
  const EpubChapterText({required this.title, required this.html});
  final String title;
  final String html;
}

/// Max bytes of an EPUB (zip) read into memory. Bounds zip-bomb / huge files.
///
/// SHORTCUT: flat cap; raise/stream for very large books if needed. Named per
/// the Threat Model.
const int kMaxEpubBytes = 32 * 1024 * 1024;

/// Parses EPUB [bytes] into a flat list of chapters (sub-chapters inlined in
/// reading order). Never throws: malformed/empty/oversized → empty list.
Future<List<EpubChapterText>> parseEpub(
  List<int> bytes, {
  int maxBytes = kMaxEpubBytes,
}) async {
  if (bytes.isEmpty || bytes.length > maxBytes) {
    return const <EpubChapterText>[];
  }
  try {
    final book = await EpubReader.readBook(bytes);
    final out = <EpubChapterText>[];
    void walk(List<EpubChapter>? chapters) {
      if (chapters == null) return;
      for (final c in chapters) {
        final html = c.HtmlContent ?? '';
        if (html.trim().isNotEmpty) {
          out.add(EpubChapterText(title: c.Title ?? '', html: html));
        }
        walk(c.SubChapters);
      }
    }

    walk(book.Chapters);
    return out;
  } catch (_) {
    return const <EpubChapterText>[];
  }
}
