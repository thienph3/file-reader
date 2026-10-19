import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
import '../viewer_scaffold.dart';
import 'office_extract.dart';

/// Max rows the non-virtualised table renders (same rationale as the CSV
/// viewer's cap — bound the per-frame widget build on large sheets).
const int kMaxXlsxRenderedRows = 500;

/// `.xlsx` viewer: shows the first sheet's cells in a scrollable table.
///
/// [rows] may be injected for tests; otherwise the file is read and extracted.
class XlsxViewer extends StatefulWidget {
  const XlsxViewer({super.key, required this.file, this.rows});

  final FileRef file;
  final List<List<String>>? rows;

  @override
  State<XlsxViewer> createState() => _XlsxViewerState();
}

class _XlsxViewerState extends State<XlsxViewer> {
  late Future<List<List<String>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.rows != null
        ? Future<List<List<String>>>.value(widget.rows!)
        : _load();
  }

  Future<List<List<String>>> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return extractXlsxTable(bytes);
    } catch (_) {
      return const <List<String>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: FutureBuilder<List<List<String>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const ViewerLoading();
          }
          final all = snap.data ?? const <List<String>>[];
          if (all.isEmpty) {
            return const ViewerEmpty(
              icon: Icons.table_chart_outlined,
              title: 'Empty or unreadable spreadsheet.',
            );
          }
          final header = all.first;
          final allData = all.skip(1).toList();
          final capped = allData.length > kMaxXlsxRenderedRows;
          final dataRows =
              capped ? allData.sublist(0, kMaxXlsxRenderedRows) : allData;
          final colCount =
              all.fold<int>(0, (m, r) => r.length > m ? r.length : m);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ExtractionBadge(label: 'First sheet, cell values only'),
              if (capped)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Large sheet — showing the first '
                    '$kMaxXlsxRenderedRows of ${allData.length} rows.',
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
                        for (var i = 0; i < colCount; i++)
                          DataColumn(
                            label: Text(i < header.length ? header[i] : ''),
                          ),
                      ],
                      rows: <DataRow>[
                        for (final row in dataRows)
                          DataRow(
                            cells: <DataCell>[
                              for (var i = 0; i < colCount; i++)
                                DataCell(
                                    Text(i < row.length ? row[i] : '')),
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
