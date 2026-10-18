import 'package:flutter/widgets.dart';

import 'file_ref.dart';
import 'file_type.dart';

/// Builds the viewer widget for a given [FileRef].
typedef ViewerBuilder = Widget Function(FileRef file);

/// Resolves a [FileType] to the viewer that renders it.
///
/// The registry is the single routing contract between the explorer and the
/// viewers: the explorer never branches on format, it only asks the registry
/// "can you open this, and if so, with what?". A `null` from [resolve] means
/// unsupported — the explorer responds by showing the Unsupported-file modal
/// instead of pushing a route. See the plan's "Navigation & flow".
class ViewerRegistry {
  ViewerRegistry(Map<FileType, ViewerBuilder> builders)
      : _builders = Map<FileType, ViewerBuilder>.unmodifiable(builders);

  final Map<FileType, ViewerBuilder> _builders;

  /// Whether a viewer is registered for [type]. [FileType.unsupported] is
  /// never supported, regardless of the map.
  bool isSupported(FileType type) =>
      type != FileType.unsupported && _builders.containsKey(type);

  /// Returns the builder for [type], or `null` when unsupported.
  ViewerBuilder? resolve(FileType type) {
    if (type == FileType.unsupported) {
      return null;
    }
    return _builders[type];
  }
}
