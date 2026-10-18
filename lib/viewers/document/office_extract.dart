import 'dart:typed_data';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

/// Max bytes of a document read for extraction.
///
/// SHORTCUT: flat cap bounds memory + zip-bomb blast radius on untrusted docx/
/// xlsx (both are zip archives). Raise/stream if users hit it. Named per the
/// Threat Model.
const int kMaxDocBytes = 16 * 1024 * 1024;

/// Extracts plain text from a `.docx` byte buffer. Content only — no layout.
///
/// Safe by contract: never throws. Malformed/empty/oversized input → ''.
String extractDocxText(List<int> bytes, {int maxBytes = kMaxDocBytes}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return '';
  try {
    return docxToText(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  } catch (_) {
    return '';
  }
}

/// Extracts the first sheet of an `.xlsx` as rows of string cells.
///
/// Safe by contract: never throws. Malformed/empty/oversized input → `[]`.
/// Cells are stringified (null → ''); values are display-only.
List<List<String>> extractXlsxTable(
  List<int> bytes, {
  int maxBytes = kMaxDocBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return const <List<String>>[];
  try {
    final decoder = SpreadsheetDecoder.decodeBytes(bytes);
    final tables = decoder.tables;
    if (tables.isEmpty) return const <List<String>>[];
    final first = tables.values.first;
    return first.rows
        .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
        .toList();
  } catch (_) {
    return const <List<String>>[];
  }
}
