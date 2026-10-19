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

/// One worksheet of a workbook: its [name] and its [rows] of string cells.
class XlsxSheet {
  const XlsxSheet({required this.name, required this.rows});
  final String name;
  final List<List<String>> rows;
}

/// Extracts **all** sheets of an `.xlsx` as [XlsxSheet]s, in workbook order.
///
/// Safe by contract: never throws. Malformed/empty/oversized input → `[]`.
/// Cells are stringified (null → ''); values are display-only.
List<XlsxSheet> extractXlsxWorkbook(
  List<int> bytes, {
  int maxBytes = kMaxDocBytes,
}) {
  if (bytes.isEmpty || bytes.length > maxBytes) return const <XlsxSheet>[];
  try {
    final decoder = SpreadsheetDecoder.decodeBytes(bytes);
    final out = <XlsxSheet>[];
    for (final entry in decoder.tables.entries) {
      out.add(XlsxSheet(
        name: entry.key,
        rows: entry.value.rows
            .map((row) => row.map((c) => c?.toString() ?? '').toList())
            .toList(),
      ));
    }
    return out;
  } catch (_) {
    return const <XlsxSheet>[];
  }
}

/// Spreadsheet column label for a 0-based column index: 0→A, 25→Z, 26→AA,
/// 27→AB, … (bijective base-26, like Excel). Pure.
String columnLabel(int index) {
  if (index < 0) return '';
  var i = index;
  final buf = StringBuffer();
  while (true) {
    final rem = i % 26;
    buf.write(String.fromCharCode(65 + rem));
    i = i ~/ 26 - 1;
    if (i < 0) break;
  }
  return String.fromCharCodes(buf.toString().codeUnits.reversed);
}
