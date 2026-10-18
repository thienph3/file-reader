/// Max characters of RTF processed; bounds work on untrusted input.
///
/// SHORTCUT: flat cap — RTF is rarely huge for a reader; raise if needed.
const int kMaxRtfChars = 4 * 1024 * 1024;

/// RTF "destination" control words whose entire group is metadata, not body
/// text, and should be skipped wholesale.
const Set<String> _skipDestinations = <String>{
  'fonttbl', 'colortbl', 'stylesheet', 'info', 'pict', 'object', 'themedata',
  'colorschememapping', 'latentstyles', 'datastore', 'generator', 'listtable',
  'listoverridetable', 'rsidtbl', 'mmathPr',
};

/// Best-effort conversion of RTF source to plain text (content, not fidelity).
///
/// Skips destination groups (font/color/style tables, info, pictures), strips
/// control words/symbols, maps `\par`/`\line`/`\tab` to whitespace, and decodes
/// `\'xx` hex escapes. Never throws; oversized input is truncated first. This
/// is a lossy extractor, not an RTF renderer.
String rtfToText(String raw, {int maxChars = kMaxRtfChars}) {
  if (raw.isEmpty) return '';
  final src = raw.length > maxChars ? raw.substring(0, maxChars) : raw;
  final out = StringBuffer();
  // Per-group "are we inside a skipped destination" flags, one per `{` depth.
  final skipStack = <bool>[false];

  var i = 0;
  while (i < src.length) {
    final ch = src[i];
    if (ch == '{') {
      // Inherit the parent's skip state into the new group.
      skipStack.add(skipStack.last);
      i += 1;
      continue;
    }
    if (ch == '}') {
      if (skipStack.length > 1) skipStack.removeLast();
      i += 1;
      continue;
    }
    if (ch == '\\') {
      if (i + 1 < src.length) {
        final next = src[i + 1];
        if (next == "'" && i + 3 < src.length) {
          final code = int.tryParse(src.substring(i + 2, i + 4), radix: 16);
          if (code != null && !skipStack.last) out.writeCharCode(code);
          i += 4;
          continue;
        }
        // Ignorable destination marker: \* → skip this group.
        if (next == '*') {
          skipStack[skipStack.length - 1] = true;
          i += 2;
          continue;
        }
        if (RegExp(r'[a-zA-Z]').hasMatch(next)) {
          final m =
              RegExp(r'\\([a-zA-Z]+)(-?\d+)? ?').matchAsPrefix(src, i);
          if (m != null) {
            final word = m.group(1)!;
            if (_skipDestinations.contains(word)) {
              // This control word opens a destination group → skip the group.
              skipStack[skipStack.length - 1] = true;
            } else if (!skipStack.last) {
              if (word == 'par' || word == 'line') {
                out.write('\n');
              } else if (word == 'tab') {
                out.write('\t');
              }
            }
            i = m.end;
            continue;
          }
        }
        if (!skipStack.last && (next == '{' || next == '}' || next == '\\')) {
          out.write(next);
        }
        i += 2;
        continue;
      }
      i += 1;
      continue;
    }
    if (ch == '\n' || ch == '\r') {
      i += 1;
      continue;
    }
    if (!skipStack.last) out.write(ch);
    i += 1;
  }
  return out.toString().trim();
}
