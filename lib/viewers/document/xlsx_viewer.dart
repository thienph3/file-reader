import 'dart:io';

import 'package:flutter/material.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
import '../viewer_scaffold.dart';
import 'office_extract.dart';

/// Max data rows / columns a sheet renders. `TableView` is lazy (builds only
/// visible cells), but caps still bound total extent + memory on huge sheets.
const int kMaxXlsxRenderedRows = 2000;
const int kMaxXlsxRenderedCols = 200;

/// `.xlsx` viewer — a read-only, Excel-mobile-style grid: spreadsheet column
/// letters (A, B, …) across the pinned top, 1-based row numbers down the pinned
/// left, a green header accent, sheet tabs at the bottom, and a zoom control to
/// scale cells for readability. No editing.
///
/// [workbook] may be injected for tests; otherwise the file is read + extracted.
class XlsxViewer extends StatefulWidget {
  const XlsxViewer({super.key, required this.file, this.workbook});

  final FileRef file;
  final List<XlsxSheet>? workbook;

  @override
  State<XlsxViewer> createState() => _XlsxViewerState();
}

class _XlsxViewerState extends State<XlsxViewer> {
  late Future<List<XlsxSheet>> _future;
  int _sheet = 0;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _future = widget.workbook != null
        ? Future<List<XlsxSheet>>.value(widget.workbook!)
        : _load();
  }

  Future<List<XlsxSheet>> _load() async {
    try {
      final bytes = await File(widget.file.path).readAsBytes();
      return extractXlsxWorkbook(bytes);
    } catch (_) {
      return const <XlsxSheet>[];
    }
  }

  void _zoom(double delta) =>
      setState(() => _scale = (_scale + delta).clamp(0.6, 2.4));

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      actions: <Widget>[
        IconButton(
          tooltip: 'Zoom out',
          icon: const Icon(Icons.zoom_out),
          onPressed: () => _zoom(-0.2),
        ),
        IconButton(
          tooltip: 'Zoom in',
          icon: const Icon(Icons.zoom_in),
          onPressed: () => _zoom(0.2),
        ),
      ],
      child: FutureBuilder<List<XlsxSheet>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const ViewerLoading();
          }
          final workbook = snap.data ?? const <XlsxSheet>[];
          if (workbook.isEmpty) {
            return const ViewerEmpty(
              icon: Icons.table_chart_outlined,
              title: 'Empty or unreadable spreadsheet.',
            );
          }
          final sheetIndex = _sheet.clamp(0, workbook.length - 1);
          final sheet = workbook[sheetIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ExtractionBadge(label: 'Cell values only — read-only'),
              Expanded(child: _SheetGrid(sheet: sheet, scale: _scale)),
              if (workbook.length > 1)
                _SheetTabs(
                  names: workbook.map((s) => s.name).toList(),
                  selected: sheetIndex,
                  onSelect: (i) => setState(() => _sheet = i),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The green-accented spreadsheet grid for one sheet, built on [TableView].
class _SheetGrid extends StatelessWidget {
  const _SheetGrid({required this.sheet, required this.scale});

  final XlsxSheet sheet;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const green = Color(0xFF217346); // Excel green
    final dataRowCount =
        sheet.rows.length.clamp(0, kMaxXlsxRenderedRows);
    final dataColCount = sheet.rows
        .fold<int>(0, (m, r) => r.length > m ? r.length : m)
        .clamp(0, kMaxXlsxRenderedCols);

    if (dataRowCount == 0 || dataColCount == 0) {
      return const ViewerEmpty(
          icon: Icons.table_chart_outlined, title: 'This sheet is empty.');
    }

    // +1 for the header row (column letters) and +1 for the number column.
    final columnCount = dataColCount + 1;
    final rowCount = dataRowCount + 1;

    const double numColWidth = 48; // pinned row-number column
    final cellW = 104.0 * scale;
    final cellH = 36.0 * scale;

    return TableView.builder(
      columnCount: columnCount,
      rowCount: rowCount,
      pinnedColumnCount: 1, // row numbers
      pinnedRowCount: 1, // column letters
      columnBuilder: (int column) => TableSpan(
        extent: FixedTableSpanExtent(column == 0 ? numColWidth : cellW),
      ),
      rowBuilder: (int row) => TableSpan(
        extent: FixedTableSpanExtent(cellH),
      ),
      cellBuilder: (BuildContext context, TableVicinity v) {
        final isHeaderRow = v.row == 0;
        final isNumberCol = v.column == 0;
        final isHeader = isHeaderRow || isNumberCol;

        String text;
        if (isHeaderRow && isNumberCol) {
          text = '';
        } else if (isHeaderRow) {
          text = columnLabel(v.column - 1); // A, B, C…
        } else if (isNumberCol) {
          text = '${v.row}'; // 1, 2, 3…
        } else {
          final r = v.row - 1;
          final c = v.column - 1;
          final row = sheet.rows[r];
          text = c < row.length ? row[c] : '';
        }

        return TableViewCell(
          child: Container(
            alignment:
                isNumberCol ? Alignment.center : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isHeader
                  ? green.withValues(alpha: 0.12)
                  : scheme.surface,
              border: Border(
                right: BorderSide(color: scheme.outlineVariant, width: 0.4),
                bottom: BorderSide(color: scheme.outlineVariant, width: 0.4),
              ),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                color: isHeader ? green : scheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet-tab strip (Excel-mobile style) for switching sheets.
class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.names,
    required this.selected,
    required this.onSelect,
  });

  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const green = Color(0xFF217346);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < names.length; i++)
              InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == selected ? green : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    names[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          i == selected ? FontWeight.w600 : FontWeight.w400,
                      color: i == selected ? green : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
