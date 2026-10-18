import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../file_loader.dart';
import '../viewer_scaffold.dart';
import 'content_format.dart';

/// Max data rows the non-virtualised table renders at once. Within the 5 MB
/// byte cap a CSV can still be tens of thousands of rows; this bounds the
/// per-frame widget build. See the SHORTCUT note in [CsvViewer.build].
const int kMaxCsvRenderedRows = 500;

/// CSV viewer: renders rows in a scrollable table. Oversized input falls back
/// to a raw-text message; a ragged/malformed file still renders what parsed.
class CsvViewer extends StatefulWidget {
  const CsvViewer({super.key, required this.file, this.content});

  final FileRef file;
  final String? content;

  @override
  State<CsvViewer> createState() => _CsvViewerState();
}

class _CsvViewerState extends State<CsvViewer> {
  late Future<LoadedText> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.content != null
        ? Future<LoadedText>.value(
            LoadedText(widget.content!, truncated: false))
        : loadText(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: FutureBuilder<LoadedText>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(
              child: Text('Could not open file.',
                  style: TextStyle(color: Colors.red)),
            );
          }
          final parsed = parseCsv(snap.data!.text);
          if (parsed.tooLarge) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('File is too large to display as a table.'),
              ),
            );
          }
          if (parsed.rows.isEmpty) {
            return const Center(child: Text('Empty file.'));
          }
          final header = parsed.rows.first;
          // SHORTCUT: non-virtualised DataTable builds every rendered row in one
          // frame, so cap the rendered rows to keep a within-byte-cap file from
          // janking the UI. Ceiling = kMaxCsvRenderedRows; upgrade path is a
          // lazily-built / paginated table (PaginatedDataTable) to show all rows.
          final allData = parsed.rows.skip(1).toList();
          final bool rowCapped = allData.length > kMaxCsvRenderedRows;
          final dataRows =
              rowCapped ? allData.sublist(0, kMaxCsvRenderedRows) : allData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (rowCapped)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Large table — showing the first '
                    '$kMaxCsvRenderedRows of ${allData.length} rows.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: <DataColumn>[
                        for (final cell in header)
                          DataColumn(label: Text(cell.toString())),
                      ],
                      rows: <DataRow>[
                        for (final row in dataRows)
                          DataRow(
                            cells: <DataCell>[
                              for (var i = 0; i < header.length; i++)
                                DataCell(Text(
                                    i < row.length ? row[i].toString() : '')),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
