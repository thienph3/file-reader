import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:mime/mime.dart';
import 'package:xml/xml.dart';

/// Max bytes of a `.docx` read for structured rendering.
///
/// SHORTCUT: flat cap bounds memory on untrusted zip input. Named per the
/// Threat Model.
const int kMaxDocxHtmlBytes = 16 * 1024 * 1024;

/// Max bytes of a single inline image embedded as a data URI. Images larger
/// than this are skipped (not fatal) — bounds the base64 blow-up in the HTML.
const int kMaxDocxImageBytes = 4 * 1024 * 1024;

/// Converts a `.docx` byte buffer to a structured **HTML body fragment**:
/// headings, bold/italic/underline runs, paragraphs, (flat) lists, tables, and
/// inline images (as `data:` URIs). Structural fidelity — not pixel-perfect
/// page layout.
///
/// Safe by contract: never throws. Malformed/empty/oversized input, or a doc
/// with no readable body, returns '' (the viewer then falls back to plain text
/// or an empty state).
String docxToHtml(
  List<int> bytes, {
  int maxBytes = kMaxDocxHtmlBytes,
  int maxImageBytes = kMaxDocxImageBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return '';
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = _fileString(archive, 'word/document.xml');
    if (documentXml == null) return '';

    // relationship id -> media path (word/media/...), for inline images.
    final rels = _readRels(archive);
    final media = <String, List<int>>{};
    for (final f in archive.files) {
      if (f.isFile && f.name.startsWith('word/media/')) {
        final c = f.content;
        if (c is List<int>) media[f.name] = c;
      }
    }

    final doc = XmlDocument.parse(documentXml);
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return '';

    final out = StringBuffer();
    final listBuffer = <String>[]; // collects consecutive list items

    void flushList() {
      if (listBuffer.isEmpty) return;
      out.write('<ul>');
      for (final li in listBuffer) {
        out.write('<li>$li</li>');
      }
      out.write('</ul>');
      listBuffer.clear();
    }

    for (final block in body.childElements) {
      switch (block.name.local) {
        case 'p':
          final inline = _paragraphInline(block, rels, media, maxImageBytes);
          if (_isListParagraph(block)) {
            listBuffer.add(inline);
          } else {
            flushList();
            final heading = _headingLevel(block);
            final align = _styleAttr(<String?>[_alignStyle(block)]);
            if (inline.trim().isEmpty) {
              out.write('<p></p>');
            } else if (heading != null) {
              out.write('<h$heading$align>$inline</h$heading>');
            } else {
              out.write('<p$align>$inline</p>');
            }
          }
        case 'tbl':
          flushList();
          out.write(_table(block));
      }
    }
    flushList();
    return out.toString();
  } catch (_) {
    return '';
  }
}

String? _fileString(Archive a, String name) {
  for (final f in a.files) {
    if (f.name == name && f.isFile) {
      final c = f.content;
      if (c is List<int>) return utf8.decode(c, allowMalformed: true);
    }
  }
  return null;
}

/// Reads `word/_rels/document.xml.rels` into {relId: target-path-within-zip}.
Map<String, String> _readRels(Archive a) {
  final out = <String, String>{};
  final xmlStr = _fileString(a, 'word/_rels/document.xml.rels');
  if (xmlStr == null) return out;
  try {
    final doc = XmlDocument.parse(xmlStr);
    for (final r in doc.findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) {
        // Targets are relative to word/, e.g. "media/image1.png".
        final norm = target.startsWith('/')
            ? target.substring(1)
            : 'word/${target.replaceFirst('./', '')}';
        out[id] = norm;
      }
    }
  } catch (_) {/* best-effort */}
  return out;
}

int? _headingLevel(XmlElement p) {
  for (final s in p.findAllElements('w:pStyle')) {
    final v = s.getAttribute('w:val') ?? '';
    final m = RegExp(r'^Heading(\d)', caseSensitive: false).firstMatch(v);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      return n.clamp(1, 6);
    }
  }
  return null;
}

bool _isListParagraph(XmlElement p) =>
    p.findAllElements('w:numPr').isNotEmpty;

/// Inline HTML for a paragraph's runs (styled text + inline images). Only
/// direct `w:r` runs of this paragraph (not descendants of nested tables, which
/// are handled by [_table]).
String _paragraphInline(
  XmlElement p,
  Map<String, String> rels,
  Map<String, List<int>> media,
  int maxImageBytes,
) {
  final buf = StringBuffer();
  for (final r in p.findElements('w:r')) {
    // Inline image embed, if any.
    final embed = _runImageEmbed(r);
    if (embed != null) {
      final path = rels[embed];
      final data = path == null ? null : media[path];
      if (data != null && data.length <= maxImageBytes) {
        final mime = lookupMimeType(path!) ?? 'image/png';
        final b64 = base64Encode(data);
        buf.write('<img src="data:$mime;base64,$b64"/>');
      }
    }
    final text = r.findElements('w:t').map((e) => e.innerText).join();
    if (text.isEmpty) continue;
    var html = _escape(text);
    final rPr = r.findElements('w:rPr').firstOrNull;
    if (rPr != null) {
      // Sanitized inline color / size / highlight → a wrapping span.
      final style = _styleAttr(<String?>[
        _colorStyle(rPr.findElements('w:color').firstOrNull?.getAttribute('w:val')),
        _sizeStyle(rPr.findElements('w:sz').firstOrNull?.getAttribute('w:val')),
        _highlightStyle(
            rPr.findElements('w:highlight').firstOrNull?.getAttribute('w:val')),
      ]);
      if (style.isNotEmpty) html = '<span$style>$html</span>';
      if (rPr.findElements('w:u').isNotEmpty) html = '<u>$html</u>';
      if (rPr.findElements('w:i').isNotEmpty) html = '<em>$html</em>';
      if (rPr.findElements('w:b').isNotEmpty) html = '<strong>$html</strong>';
    }
    buf.write(html);
  }
  return buf.toString();
}

/// Finds an image relationship id inside a run's drawing, if present.
String? _runImageEmbed(XmlElement run) {
  for (final blip in run.findAllElements('a:blip')) {
    final id = blip.getAttribute('r:embed') ?? blip.getAttribute('r:link');
    if (id != null) return id;
  }
  return null;
}

String _table(XmlElement tbl) {
  final buf = StringBuffer('<table>');
  for (final tr in tbl.findElements('w:tr')) {
    buf.write('<tr>');
    for (final tc in tr.findElements('w:tc')) {
      // Cell text = concatenation of its paragraphs' text runs.
      final cellText = tc
          .findAllElements('w:t')
          .map((e) => e.innerText)
          .join(' ')
          .trim();
      buf.write('<td>${_escape(cellText)}</td>');
    }
    buf.write('</tr>');
  }
  buf.write('</table>');
  return buf.toString();
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

// ---- Sanitized style mapping -------------------------------------------------
// Untrusted docx values NEVER reach a `style=` attribute unvalidated. Colors
// must be exactly 6 hex digits; sizes must be a bounded positive integer;
// highlight and alignment come from fixed whitelists. Anything else is dropped.

final RegExp _hex6 = RegExp(r'^[0-9A-Fa-f]{6}$');

/// `w:color@w:val` → `color:#RRGGBB` or null (for 'auto' / invalid).
String? _colorStyle(String? val) =>
    (val != null && _hex6.hasMatch(val)) ? 'color:#$val' : null;

/// `w:sz@w:val` is in half-points → `font-size:Npx`. Clamped to a sane range.
String? _sizeStyle(String? val) {
  final halfPts = int.tryParse(val ?? '');
  if (halfPts == null || halfPts <= 0) return null;
  final pt = (halfPts / 2).clamp(6, 96);
  return 'font-size:${pt.toStringAsFixed(0)}px';
}

/// `w:highlight@w:val` is a named color → a whitelisted CSS background.
const Map<String, String> _highlightColors = <String, String>{
  'yellow': '#ffff00', 'green': '#00ff00', 'cyan': '#00ffff',
  'magenta': '#ff00ff', 'blue': '#0000ff', 'red': '#ff0000',
  'darkBlue': '#000080', 'darkCyan': '#008080', 'darkGreen': '#008000',
  'darkMagenta': '#800080', 'darkRed': '#800000', 'darkYellow': '#808000',
  'darkGray': '#808080', 'lightGray': '#c0c0c0', 'black': '#000000',
};
String? _highlightStyle(String? val) {
  final css = _highlightColors[val];
  return css == null ? null : 'background-color:$css';
}

/// `w:jc@w:val` → `text-align:...` from a fixed whitelist.
const Map<String, String> _alignMap = <String, String>{
  'left': 'left', 'start': 'left',
  'right': 'right', 'end': 'right',
  'center': 'center', 'both': 'justify', 'distribute': 'justify',
};
String? _alignStyle(XmlElement p) {
  for (final jc in p.findElements('w:pPr')) {
    for (final e in jc.findElements('w:jc')) {
      final css = _alignMap[e.getAttribute('w:val')];
      if (css != null) return 'text-align:$css';
    }
  }
  return null;
}

/// Joins non-null style fragments into a safe ` style="..."` attribute, or ''.
String _styleAttr(Iterable<String?> parts) {
  final kept = parts.whereType<String>().toList();
  return kept.isEmpty ? '' : ' style="${kept.join(';')}"';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
