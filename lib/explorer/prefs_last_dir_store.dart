import 'package:shared_preferences/shared_preferences.dart';

import 'last_dir_store.dart';

/// Production [LastDirStore] backed by `SharedPreferencesAsync` (the current
/// recommended API — see docs/tech.md). Stores only the directory path string,
/// never file contents.
class PrefsLastDirStore implements LastDirStore {
  PrefsLastDirStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const String _key = 'last_dir';
  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String path) => _prefs.setString(_key, path);
}
