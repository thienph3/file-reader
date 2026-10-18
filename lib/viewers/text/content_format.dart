import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

/// Maximum bytes/characters a viewer will parse-and-pretty-print in memory.
///
/// SHORTCUT: flat 5 MB cap for structured formatting — move to streamed/
/// windowed parsing if users routinely open larger JSON/XML/CSV. Named per the
/// Threat Model (bound DoS from a malformed/huge file). Plain text uses its own
/// streamed path and is not subject to this.
const int kMaxFormatBytes = 5 * 1024 * 1024;

/// Result of attempting to format structured text. When [ok] is false the
/// viewer falls back to showing [raw] as plain text (never throws to the UI).
class FormatResult {
  const FormatResult.ok(this.text)
      : ok = true,
        raw = null;
  const FormatResult.fallback(this.raw)
      : ok = false,
        text = null;

  final bool ok;

  /// Pretty-printed output when [ok].
  final String? text;

  /// Original input to show as-is when formatting failed or was skipped.
  final String? raw;
}

bool _tooLarge(String input) => input.length > kMaxFormatBytes;

/// Pretty-prints JSON with 2-space indent. Malformed input or oversized input
/// falls back to raw text. Never throws.
FormatResult formatJson(String input) {
  if (_tooLarge(input)) {
    return FormatResult.fallback(input);
  }
  try {
    final Object? decoded = jsonDecode(input);
    return FormatResult.ok(const JsonEncoder.withIndent('  ').convert(decoded));
  } on FormatException {
    return FormatResult.fallback(input);
  }
}

/// Pretty-prints XML with 2-space indent.
///
/// `package:xml` does not resolve external DTD entities or fetch external
/// resources, so there is no XXE/external-entity expansion to exploit (see
/// docs/tech.md). Malformed or oversized input falls back to raw. Never throws.
FormatResult formatXml(String input) {
  if (_tooLarge(input)) {
    return FormatResult.fallback(input);
  }
  try {
    final doc = XmlDocument.parse(input);
    return FormatResult.ok(doc.toXmlString(pretty: true, indent: '  '));
  } on XmlException {
    return FormatResult.fallback(input);
  }
}

/// Parses CSV into rows. Oversized input returns an empty list with
/// [CsvParseResult.tooLarge] set so the viewer can show a raw fallback.
/// Malformed rows are tolerated by the parser (PapaParse-style). Never throws.
class CsvParseResult {
  const CsvParseResult(this.rows, {this.tooLarge = false});
  final List<List<dynamic>> rows;
  final bool tooLarge;
}

CsvParseResult parseCsv(String input) {
  if (_tooLarge(input)) {
    return const CsvParseResult(<List<dynamic>>[], tooLarge: true);
  }
  // dynamicTyping: false keeps every field a String — correct for a viewer and
  // avoids surprising numeric coercion. autoDetect handles , ; \t | delimiters.
  final rows = Csv(dynamicTyping: false).decode(input);
  return CsvParseResult(rows);
}
