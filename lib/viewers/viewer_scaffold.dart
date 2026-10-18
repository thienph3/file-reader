import 'package:flutter/material.dart';

/// Shared chrome for every viewer: an app bar with a back affordance, the file
/// name as title, and an optional trailing action (e.g. a view/raw toggle).
/// Pressing back pops the route, returning to the explorer (see plan's
/// "Navigation & flow"). The back arrow is provided automatically by the
/// pushed route; this widget just standardises title + actions + body.
class ViewerScaffold extends StatelessWidget {
  const ViewerScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: child,
    );
  }
}

/// A simple two-option segmented toggle used by viewers (e.g. VIEW / RAW).
class ViewerToggle extends StatelessWidget {
  const ViewerToggle({
    super.key,
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SegmentedButton<bool>(
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: <ButtonSegment<bool>>[
          ButtonSegment<bool>(value: true, label: Text(left)),
          ButtonSegment<bool>(value: false, label: Text(right)),
        ],
        selected: <bool>{leftSelected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
