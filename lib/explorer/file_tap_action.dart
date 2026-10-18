import '../core/file_ref.dart';
import '../core/file_type.dart';
import '../core/viewer_registry.dart';

/// What the explorer should do when the user taps a file entry.
///
/// This is a pure decision — no navigation, no I/O — so it can be unit-tested
/// and the widget layer just executes the result. See the plan's
/// "Navigation & flow": a supported file pushes a viewer; an unsupported one
/// shows the modal and stays in the explorer.
sealed class FileTapAction {
  const FileTapAction();
}

/// Push a viewer route for [file].
class OpenViewer extends FileTapAction {
  const OpenViewer(this.file);
  final FileRef file;

  @override
  bool operator ==(Object other) =>
      other is OpenViewer && other.file == file;
  @override
  int get hashCode => file.hashCode;
}

/// Show the Unsupported-file modal for a file named [fileName] with
/// extension-derived [type]. No route is pushed.
class ShowUnsupported extends FileTapAction {
  const ShowUnsupported({required this.fileName, required this.type});
  final String fileName;
  final FileType type;

  @override
  bool operator ==(Object other) =>
      other is ShowUnsupported &&
      other.fileName == fileName &&
      other.type == type;
  @override
  int get hashCode => Object.hash(fileName, type);
}

/// Decides what happens when the user taps a file.
///
/// [registry] is consulted to see if the detected [FileRef.type] has a viewer.
/// Supported → [OpenViewer]; otherwise → [ShowUnsupported]. This never throws
/// and never performs I/O.
FileTapAction resolveFileTap(FileRef file, ViewerRegistry registry) {
  if (registry.isSupported(file.type)) {
    return OpenViewer(file);
  }
  return ShowUnsupported(fileName: file.name, type: file.type);
}
