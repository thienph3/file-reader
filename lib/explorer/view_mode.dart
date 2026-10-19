import 'package:shared_preferences/shared_preferences.dart';

import 'explorer_sort.dart';

/// How the explorer lays out a directory's entries.
enum ViewMode {
  /// Compact rows: icon + name + size.
  list,

  /// Two-line rows: thumbnail/icon + name + type · size · date.
  detail,

  /// 3-column tiles with thumbnails/icons.
  grid,

  /// 2-column large gallery tiles.
  largeGrid,
}

/// The explorer's persisted view/sort preferences.
class ExplorerPrefs {
  const ExplorerPrefs({
    this.viewMode = ViewMode.list,
    this.sortField = SortField.name,
    this.sortDirection = SortDirection.ascending,
    this.foldersFirst = true,
    this.showHidden = false,
  });

  final ViewMode viewMode;
  final SortField sortField;
  final SortDirection sortDirection;
  final bool foldersFirst;
  final bool showHidden;

  ExplorerPrefs copyWith({
    ViewMode? viewMode,
    SortField? sortField,
    SortDirection? sortDirection,
    bool? foldersFirst,
    bool? showHidden,
  }) =>
      ExplorerPrefs(
        viewMode: viewMode ?? this.viewMode,
        sortField: sortField ?? this.sortField,
        sortDirection: sortDirection ?? this.sortDirection,
        foldersFirst: foldersFirst ?? this.foldersFirst,
        showHidden: showHidden ?? this.showHidden,
      );

  @override
  bool operator ==(Object other) =>
      other is ExplorerPrefs &&
      other.viewMode == viewMode &&
      other.sortField == sortField &&
      other.sortDirection == sortDirection &&
      other.foldersFirst == foldersFirst &&
      other.showHidden == showHidden;

  @override
  int get hashCode => Object.hash(
      viewMode, sortField, sortDirection, foldersFirst, showHidden);
}

T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Persists [ExplorerPrefs]. Abstracted so explorer logic is testable without
/// `shared_preferences`.
abstract class ExplorerPrefsStore {
  Future<ExplorerPrefs> read();
  Future<void> write(ExplorerPrefs prefs);
}

/// Production store backed by `SharedPreferencesAsync`. Stores only enum names
/// and booleans — no file data.
class PrefsExplorerPrefsStore implements ExplorerPrefsStore {
  PrefsExplorerPrefsStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  static const _kView = 'view_mode';
  static const _kField = 'sort_field';
  static const _kDir = 'sort_dir';
  static const _kFolders = 'folders_first';
  static const _kHidden = 'show_hidden';

  @override
  Future<ExplorerPrefs> read() async {
    return ExplorerPrefs(
      viewMode: _byName(ViewMode.values, await _prefs.getString(_kView),
          ViewMode.list),
      sortField: _byName(SortField.values, await _prefs.getString(_kField),
          SortField.name),
      sortDirection: _byName(SortDirection.values,
          await _prefs.getString(_kDir), SortDirection.ascending),
      foldersFirst: await _prefs.getBool(_kFolders) ?? true,
      showHidden: await _prefs.getBool(_kHidden) ?? false,
    );
  }

  @override
  Future<void> write(ExplorerPrefs p) async {
    await _prefs.setString(_kView, p.viewMode.name);
    await _prefs.setString(_kField, p.sortField.name);
    await _prefs.setString(_kDir, p.sortDirection.name);
    await _prefs.setBool(_kFolders, p.foldersFirst);
    await _prefs.setBool(_kHidden, p.showHidden);
  }
}
