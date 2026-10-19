import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmering placeholder list shown while a directory is being read —
/// calmer than a bare spinner and hints at the row layout to come.
class ExplorerSkeleton extends StatelessWidget {
  const ExplorerSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerLow,
      child: ListView.builder(
        // Non-interactive placeholder.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        itemBuilder: (context, _) => const _SkeletonRow(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 12, width: double.infinity, color: Colors.white),
                const SizedBox(height: 7),
                Container(height: 10, width: 120, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
