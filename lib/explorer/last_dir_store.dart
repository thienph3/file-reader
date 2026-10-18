/// Persists the explorer's "last-viewed directory" across launches.
///
/// Abstracted so the resolution logic can be unit-tested without
/// `shared_preferences`. The production implementation wraps
/// `SharedPreferencesAsync` (see docs/tech.md). Only a path string is ever
/// stored — never file contents.
abstract class LastDirStore {
  Future<String?> read();
  Future<void> write(String path);
}

/// Tests whether a directory path currently exists and is readable.
///
/// Abstracted so first-run / stale-path logic can be tested without touching
/// the real filesystem. Production wraps `dart:io` `Directory.existsSync`.
typedef DirectoryExists = bool Function(String path);

/// Resolves which directory the explorer should open on launch.
///
/// Rules (see the plan's "Navigation & flow"):
/// - No persisted path (first launch) → [storageRoot].
/// - A persisted path that still exists → that path.
/// - A persisted path that no longer exists/readable (stale) → [storageRoot],
///   and the stale value is overwritten with the root so it self-heals.
///
/// Returns the directory to show. Never throws.
Future<String> resolveInitialDirectory({
  required String storageRoot,
  required LastDirStore store,
  required DirectoryExists exists,
}) async {
  final String? last = await store.read();
  if (last == null || last.isEmpty) {
    return storageRoot;
  }
  if (exists(last)) {
    return last;
  }
  // Stale path — fall back to root and self-heal the stored value.
  await store.write(storageRoot);
  return storageRoot;
}
