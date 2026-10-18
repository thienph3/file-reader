import 'dart:convert';
import 'dart:io';

/// Reads text file content for viewers, bounded by a byte cap so a huge file
/// cannot exhaust memory (Threat Model: bound DoS). Returns the decoded string
/// and whether it was truncated.
class LoadedText {
  const LoadedText(this.text, {required this.truncated});
  final String text;
  final bool truncated;
}

/// Max bytes a text/structured viewer reads into memory at once.
///
/// SHORTCUT: single-shot bounded read — replace with windowed/streamed reading
/// for very large logs if users hit the cap often. Ceiling named per Threat Model.
const int kMaxReadBytes = 8 * 1024 * 1024;

/// Reads up to [kMaxReadBytes] of [path] as UTF-8 (lenient: invalid bytes are
/// replaced, never thrown). Throws [FileSystemException] only if the file can't
/// be opened — callers show an error state for that.
Future<LoadedText> loadText(String path) async {
  final file = File(path);
  final int length = await file.length();
  final bool truncated = length > kMaxReadBytes;
  final raf = await file.open();
  try {
    final bytes = await raf.read(truncated ? kMaxReadBytes : length);
    return LoadedText(
      utf8.decode(bytes, allowMalformed: true),
      truncated: truncated,
    );
  } finally {
    await raf.close();
  }
}
