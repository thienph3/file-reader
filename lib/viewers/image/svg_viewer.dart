import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';

/// SVG viewer: renders a vector image with pinch-zoom/pan ([InteractiveViewer]).
/// A parse/render failure shows a graceful placeholder rather than crashing.
///
/// Rendering uses flutter_svg's vector pipeline (no script execution / no
/// network); verified on-device.
class SvgViewer extends StatelessWidget {
  const SvgViewer({super.key, required this.file});

  final FileRef file;

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: file.name,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 8,
        child: Center(
          child: SvgPicture.file(
            File(file.path),
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
