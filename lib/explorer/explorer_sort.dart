import '../core/file_type.dart';
import 'directory_lister.dart';

/// Field the explorer sorts entries by.
enum SortField { name, size, date, type }

/// Sort direction.
enum SortDirection { ascending, descending }

/// Applies the user's sort + visibility preferences to a directory listing.
///
/// Pure and deterministic (testable): filters hidden entries unless
/// [showHidden], optionally groups folders before files ([foldersFirst]), then
/// orders by [field] in [direction]. Does not mutate [entries].
List<Entry> applyView(
  List<Entry> entries, {
  required SortField field,
  required SortDirection direction,
  required bool foldersFirst,
  required bool showHidden,
}) {
  final visible = <Entry>[
    for (final e in entries)
      if (showHidden || !e.isHidden) e,
  ];

  int cmp(Entry a, Entry b) {
    // Folders-first grouping takes precedence over the field when enabled.
    if (foldersFirst && a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    final int c;
    switch (field) {
      case SortField.name:
        c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortField.size:
        c = (a.size ?? -1).compareTo(b.size ?? -1);
      case SortField.date:
        final da = a.modified?.millisecondsSinceEpoch ?? 0;
        final db = b.modified?.millisecondsSinceEpoch ?? 0;
        c = da.compareTo(db);
      case SortField.type:
        c = _typeKey(a).compareTo(_typeKey(b));
    }
    // Stable tiebreak on name so equal keys have a deterministic order.
    final result = c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return direction == SortDirection.ascending ? result : -result;
  }

  final sorted = <Entry>[...visible]..sort(cmp);
  return sorted;
}

/// Sort key for type: directories group together; files group by extension/
/// detected family name.
String _typeKey(Entry e) {
  if (e.isDirectory) return '\u0000dir'; // sorts before files
  final t = e.fileRef?.type ?? FileType.unsupported;
  return t.name;
}
