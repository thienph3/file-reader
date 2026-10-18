import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';

/// PDF viewer: native rendering via `pdfx` with pinch-zoom ([PdfViewPinch]) and
/// a page indicator. A document-load error shows a graceful state instead of
/// crashing (covers corrupt/unsupported PDFs). The controller is disposed.
///
/// Actual rendering uses the platform PDF engine and is verified on-device;
/// this widget's structure (scaffold, page indicator, error state) is the
/// logic under test.
class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key, required this.file});

  final FileRef file;

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late final PdfControllerPinch _controller;
  int _page = 1;
  int? _pageCount;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.file.path),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      actions: <Widget>[
        if (!_errored && _pageCount != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_page / $_pageCount',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
      ],
      child: _errored
          ? const _PdfError()
          : PdfViewPinch(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              onDocumentLoaded: (doc) =>
                  setState(() => _pageCount = doc.pagesCount),
              onDocumentError: (_) => setState(() => _errored = true),
            ),
    );
  }
}

class _PdfError extends StatelessWidget {
  const _PdfError();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.picture_as_pdf_outlined, size: 48),
            SizedBox(height: 12),
            Text("Can't open this PDF",
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('The file may be corrupt or password-protected.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
