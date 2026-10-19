import 'package:flutter/material.dart';

import 'explorer_sort.dart';
import 'view_mode.dart';

/// Shows the sort & view options bottom sheet, returning the updated prefs
/// (or null if dismissed with no change). View mode, sort field + direction,
/// and the folders-first / show-hidden toggles. Choices are returned to the
/// caller, which persists them.
Future<ExplorerPrefs?> showExplorerOptions(
  BuildContext context,
  ExplorerPrefs current,
) {
  return showModalBottomSheet<ExplorerPrefs>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _OptionsSheet(initial: current),
  );
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.initial});
  final ExplorerPrefs initial;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late ExplorerPrefs _p = widget.initial;

  void _update(ExplorerPrefs next) {
    setState(() => _p = next);
    // Live-apply: return the latest on each change so the explorer updates
    // immediately, while the sheet stays open for further tweaks.
    // (Returned on close; see _close.)
  }

  void _tapSort(SortField field) {
    if (_p.sortField == field) {
      // Toggle direction when tapping the already-selected field.
      _update(_p.copyWith(
        sortDirection: _p.sortDirection == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending,
      ));
    } else {
      _update(_p.copyWith(sortField: field));
    }
  }

  static const _sortLabels = <SortField, String>{
    SortField.name: 'Name',
    SortField.size: 'Size',
    SortField.date: 'Date modified',
    SortField.type: 'Type',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _heading(context, 'View mode'),
            SegmentedButton<ViewMode>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<ViewMode>>[
                ButtonSegment(value: ViewMode.list, label: Text('List')),
                ButtonSegment(value: ViewMode.detail, label: Text('Detail')),
                ButtonSegment(value: ViewMode.grid, label: Text('Grid')),
                ButtonSegment(value: ViewMode.largeGrid, label: Text('Large')),
              ],
              selected: <ViewMode>{_p.viewMode},
              onSelectionChanged: (s) =>
                  _update(_p.copyWith(viewMode: s.first)),
            ),
            _heading(context, 'Sort by'),
            for (final field in SortField.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _p.sortField == field
                      ? (_p.sortDirection == SortDirection.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                      : Icons.unfold_more,
                  color: _p.sortField == field
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
                title: Text(_sortLabels[field]!),
                selected: _p.sortField == field,
                onTap: () => _tapSort(field),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Folders first'),
              value: _p.foldersFirst,
              onChanged: (v) => _update(_p.copyWith(foldersFirst: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show hidden files'),
              value: _p.showHidden,
              onChanged: (v) => _update(_p.copyWith(showHidden: v)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_p),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.outline)),
      );
}
