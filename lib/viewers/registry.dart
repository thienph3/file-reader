import '../core/file_type.dart';
import '../core/viewer_registry.dart';
import 'archive/archive_browser.dart';
import 'document/docx_viewer.dart';
import 'document/pdf_viewer.dart';
import 'document/pptx_viewer.dart';
import 'document/xlsx_viewer.dart';
import 'image/image_viewer.dart';
import 'image/svg_viewer.dart';
import 'media/audio_player_view.dart';
import 'media/video_player_view.dart';
import 'reading/epub_viewer.dart';
import 'text/csv_viewer.dart';
import 'text/html_viewer.dart';
import 'text/rtf_viewer.dart';
import 'text/structured_viewer.dart';
import 'text/text_viewer.dart';

/// The viewer registry: wires each supported [FileType] to its viewer.
///
/// `.md` routes to the plain-text viewer (Phase 1; rich Markdown is Phase 5).
/// `.pptx` shows per-slide extracted TEXT (Phase 6 — no local slide renderer
/// exists; content, not layout). Anything not in this map (and
/// [FileType.unsupported]) resolves to null → the explorer shows the
/// Unsupported-file modal.
ViewerRegistry buildPhase1Registry() {
  return ViewerRegistry(<FileType, ViewerBuilder>{
    FileType.plainText: (f) => TextViewer(file: f),
    FileType.markdown: (f) => TextViewer(file: f),
    FileType.json: (f) => StructuredViewer(file: f),
    FileType.xml: (f) => StructuredViewer(file: f),
    FileType.csv: (f) => CsvViewer(file: f),
    FileType.html: (f) => HtmlViewer(file: f),
    FileType.image: (f) => ImageViewer(file: f), // Phase 2
    FileType.pdf: (f) => PdfViewer(file: f), // Phase 3
    FileType.docx: (f) => DocxViewer(file: f), // Phase 3
    FileType.xlsx: (f) => XlsxViewer(file: f), // Phase 3
    FileType.audio: (f) => AudioViewer(file: f), // Phase 4
    FileType.video: (f) => VideoViewer(file: f), // Phase 4
    FileType.archive: (f) => ArchiveBrowser(file: f), // Phase 4 (+ cbz Phase 5)
    FileType.epub: (f) => EpubViewer(file: f), // Phase 5
    FileType.svg: (f) => SvgViewer(file: f), // Phase 5
    FileType.rtf: (f) => RtfViewer(file: f), // Phase 5
    FileType.pptx: (f) => PptxViewer(file: f), // Phase 6 (per-slide text)
  });
}
