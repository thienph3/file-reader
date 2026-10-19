import 'package:flutter/material.dart';

/// Shared, consistent viewer states — one look for loading / empty / error
/// across every viewer (mirrors the explorer's message widget), so the app
/// feels like one product regardless of file type.

/// Centered spinner for while a viewer loads its content.
class ViewerLoading extends StatelessWidget {
  const ViewerLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Centered icon + title + hint, used by both the empty and error states.
class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.title, this.hint});
  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (hint != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when a viewer has nothing to display (empty/blank content).
class ViewerEmpty extends StatelessWidget {
  const ViewerEmpty({super.key, required this.title, this.hint, this.icon});
  final String title;
  final String? hint;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => _ViewerMessage(
        icon: icon ?? Icons.inbox_outlined,
        title: title,
        hint: hint,
      );
}

/// Shown when a viewer fails to open/parse a file (graceful, never a crash).
class ViewerError extends StatelessWidget {
  const ViewerError({super.key, required this.title, this.hint, this.icon});
  final String title;
  final String? hint;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => _ViewerMessage(
        icon: icon ?? Icons.error_outline,
        title: title,
        hint: hint,
      );
}

/// A small, consistent chip telling the user that a document viewer shows
/// extracted **text/content**, not the original rendered layout — so
/// docx/xlsx/pptx/rtf read as "by design", not "rendered badly". Placed at the
/// top of those viewers.
class ExtractionBadge extends StatelessWidget {
  const ExtractionBadge({
    super.key,
    this.label = 'Text only — original layout not shown',
  });
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.info_outline, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// A shared bottom transport bar for timed media: play/pause + a seek slider +
/// elapsed/total. Audio and video use the *same* widget so the two players are
/// visually identical. Stateless — the parent owns playback and feeds values.
class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
  });

  final bool playing;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds.toDouble();
    final value =
        maxMs <= 0 ? 0.0 : position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: <Widget>[
          IconButton.filledTonal(
            iconSize: 28,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: onPlayPause,
          ),
          const SizedBox(width: 4),
          Text(_fmt(position),
              style: Theme.of(context).textTheme.labelSmall),
          Expanded(
            child: Slider(
              min: 0,
              max: maxMs <= 0 ? 1 : maxMs,
              value: value,
              onChanged: maxMs <= 0
                  ? null
                  : (v) => onSeek(Duration(milliseconds: v.toInt())),
            ),
          ),
          Text(_fmt(duration),
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// A single checkable toggle entry for [ViewerMenu].
class ViewerMenuToggle {
  const ViewerMenuToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
}

/// A consistent overflow (⋮) menu for a viewer's secondary toggles (e.g. word
/// wrap), so low-frequency options live in the same place across viewers
/// instead of as mismatched app-bar icons. Place in `ViewerScaffold.actions`.
class ViewerMenu extends StatelessWidget {
  const ViewerMenu({super.key, required this.toggles});
  final List<ViewerMenuToggle> toggles;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Options',
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => <PopupMenuEntry<int>>[
        for (var i = 0; i < toggles.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: <Widget>[
                Icon(
                  toggles[i].value
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(toggles[i].label),
              ],
            ),
          ),
      ],
      onSelected: (i) => toggles[i].onChanged(!toggles[i].value),
    );
  }
}
