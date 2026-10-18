import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// One slide's extracted text (content, not layout).
class PptxSlide {
  const PptxSlide({required this.index, required this.texts});

  /// 1-based slide number (from `slideN.xml`), in presentation order.
  final int index;

  /// Non-empty text runs on the slide, in document order.
  final List<String> texts;
}

/// Max bytes of a `.pptx` (zip) read into memory. Bounds DoS on untrusted input.
///
/// SHORTCUT: flat cap; raise/stream for very large decks if needed. Named per
/// the Threat Model.
const int kMaxPptxBytes = 32 * 1024 * 1024;

final RegExp _slideName = RegExp(r'^ppt/slides/slide(\d+)\.xml$');

/// Extracts per-slide text from a `.pptx` byte buffer.
///
/// Enumerates `ppt/slides/slideN.xml`, sorts by the numeric slide index (so
/// slide 10 follows slide 9, not slide 1), and pulls non-empty `<a:t>` runs.
/// Content only — no layout/graphics. Never throws: malformed/empty/oversized/
/// not-a-pptx → empty list.
List<PptxSlide> extractPptxSlides(
  List<int> bytes, {
  int maxBytes = kMaxPptxBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return const <PptxSlide>[];
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideFiles = <MapEntry<int, ArchiveFile>>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final m = _slideName.firstMatch(f.name);
      if (m == null) continue;
      slideFiles.add(MapEntry(int.parse(m.group(1)!), f));
    }
    slideFiles.sort((a, b) => a.key.compareTo(b.key));

    final out = <PptxSlide>[];
    for (final entry in slideFiles) {
      final content = entry.value.content;
      if (content is! List<int>) continue;
      try {
        final doc = XmlDocument.parse(String.fromCharCodes(content));
        final texts = doc
            .findAllElements('a:t')
            .map((e) => e.innerText)
            .where((t) => t.trim().isNotEmpty)
            .toList();
        out.add(PptxSlide(index: entry.key, texts: texts));
      } catch (_) {
        // A malformed slide is skipped, not fatal to the whole deck.
        out.add(PptxSlide(index: entry.key, texts: const <String>[]));
      }
    }
    return out;
  } catch (_) {
    return const <PptxSlide>[];
  }
}
