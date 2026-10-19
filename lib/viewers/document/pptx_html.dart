import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:xml/xml.dart';

/// One slide rendered to a sanitized HTML fragment (styled text + inline
/// images). Content/structure, not positioned-canvas layout.
class PptxSlideHtml {
  const PptxSlideHtml({required this.index, required this.html});
  final int index;
  final String html;
}

/// Max bytes of a `.pptx` read for styled rendering.
const int kMaxPptxHtmlBytes = 32 * 1024 * 1024;

/// Max bytes of a single inline image embedded as a data URI.
const int kMaxPptxImageBytes = 4 * 1024 * 1024;

final RegExp _slideName = RegExp(r'^ppt/slides/slide(\d+)\.xml$');

/// Converts a `.pptx` to per-slide HTML fragments (numeric slide order).
///
/// Each slide: DrawingML paragraphs (`a:p`) → styled runs (`a:r`), with
/// bold/italic/underline, sanitized text colour and font size, plus inline
/// images (`a:blip` → per-slide rels → `ppt/media`) as base64 `data:` URIs.
/// Safe by contract: never throws; malformed/empty/oversized → empty list.
List<PptxSlideHtml> pptxToHtmlSlides(
  List<int> bytes, {
  int maxBytes = kMaxPptxHtmlBytes,
  int maxImageBytes = kMaxPptxImageBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return const <PptxSlideHtml>[];
  try {
    final archive = ZipDecoder().decodeBytes(bytes);

    // All media bytes by zip path, for image embeds.
    final media = <String, List<int>>{};
    for (final f in archive.files) {
      if (f.isFile && f.name.startsWith('ppt/media/')) {
        final c = f.content;
        if (c is List<int>) media[f.name] = c;
      }
    }

    // Collect slideN.xml, numeric order.
    final slides = <MapEntry<int, ArchiveFile>>[];
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final m = _slideName.firstMatch(f.name);
      if (m != null) slides.add(MapEntry(int.parse(m.group(1)!), f));
    }
    slides.sort((a, b) => a.key.compareTo(b.key));

    final out = <PptxSlideHtml>[];
    for (final entry in slides) {
      final content = entry.value.content;
      if (content is! List<int>) continue;
      try {
        final rels = _readSlideRels(archive, entry.key);
        final doc = XmlDocument.parse(utf8.decode(content, allowMalformed: true));
        out.add(PptxSlideHtml(
          index: entry.key,
          html: _slideHtml(doc, rels, media, maxImageBytes),
        ));
      } catch (_) {
        out.add(PptxSlideHtml(index: entry.key, html: ''));
      }
    }
    return out;
  } catch (_) {
    return const <PptxSlideHtml>[];
  }
}

/// Reads `ppt/slides/_rels/slideN.xml.rels` → {relId: zip-path in ppt/media}.
Map<String, String> _readSlideRels(Archive a, int slide) {
  final out = <String, String>{};
  final name = 'ppt/slides/_rels/slide$slide.xml.rels';
  String? xmlStr;
  for (final f in a.files) {
    if (f.name == name && f.isFile) {
      final c = f.content;
      if (c is List<int>) xmlStr = utf8.decode(c, allowMalformed: true);
    }
  }
  if (xmlStr == null) return out;
  try {
    for (final r in XmlDocument.parse(xmlStr).findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) {
        // Targets like "../media/image1.png" relative to ppt/slides/.
        final norm = target.startsWith('/')
            ? target.substring(1)
            : 'ppt/slides/$target';
        out[id] = _normalize(norm);
      }
    }
  } catch (_) {/* best-effort */}
  return out;
}

/// Resolves ".." segments in a zip path (e.g. ppt/slides/../media/x → ppt/media/x).
String _normalize(String path) {
  final parts = <String>[];
  for (final seg in path.split('/')) {
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (seg != '.' && seg.isNotEmpty) {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

String _slideHtml(
  XmlDocument doc,
  Map<String, String> rels,
  Map<String, List<int>> media,
  int maxImageBytes,
) {
  final buf = StringBuffer();

  // Inline images on the slide.
  for (final blip in doc.findAllElements('a:blip')) {
    final id = blip.getAttribute('r:embed');
    final path = id == null ? null : rels[id];
    final data = path == null ? null : media[path];
    if (data != null && data.length <= maxImageBytes) {
      final mime = lookupMimeType(path!) ?? 'image/png';
      buf.write('<img src="data:$mime;base64,${base64Encode(data)}"/>');
    }
  }

  // Text paragraphs.
  for (final p in doc.findAllElements('a:p')) {
    final inner = StringBuffer();
    for (final run in p.findElements('a:r')) {
      final text = run.findElements('a:t').map((e) => e.innerText).join();
      if (text.isEmpty) continue;
      var html = _escape(text);
      final rPr = run.findElements('a:rPr').firstOrNull;
      if (rPr != null) {
        final color = rPr
            .findAllElements('a:srgbClr')
            .firstOrNull
            ?.getAttribute('val');
        final style = _styleAttr(<String?>[
          _colorStyle(color),
          _sizeStyle(rPr.getAttribute('sz')),
        ]);
        if (style.isNotEmpty) html = '<span$style>$html</span>';
        final u = rPr.getAttribute('u');
        if (u != null && u != 'none') html = '<u>$html</u>';
        if (rPr.getAttribute('i') == '1') html = '<em>$html</em>';
        if (rPr.getAttribute('b') == '1') html = '<strong>$html</strong>';
      }
      inner.write(html);
    }
    if (inner.isNotEmpty) buf.write('<p>$inner</p>');
  }
  return buf.toString();
}

// ---- Sanitized style helpers (same discipline as the docx renderer) ---------
final RegExp _hex6 = RegExp(r'^[0-9A-Fa-f]{6}$');

String? _colorStyle(String? val) =>
    (val != null && _hex6.hasMatch(val)) ? 'color:#$val' : null;

/// DrawingML `sz` is in hundredths of a point → `font-size:Npx`, clamped.
String? _sizeStyle(String? val) {
  final hundredths = int.tryParse(val ?? '');
  if (hundredths == null || hundredths <= 0) return null;
  final pt = (hundredths / 100).clamp(6, 96);
  return 'font-size:${pt.toStringAsFixed(0)}px';
}

String _styleAttr(Iterable<String?> parts) {
  final kept = parts.whereType<String>().toList();
  return kept.isEmpty ? '' : ' style="${kept.join(';')}"';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
