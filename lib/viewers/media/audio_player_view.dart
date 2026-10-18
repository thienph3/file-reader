import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';

/// Audio player: play/pause + a seek bar, via `just_audio`. Shows a graceful
/// error state if the source fails to load (e.g. an `.ogg` the device codec
/// can't decode). Disposes the player.
///
/// Playback uses the platform codec and is verified on-device; the controls +
/// error state are the logic under test.
class AudioViewer extends StatefulWidget {
  const AudioViewer({super.key, required this.file});

  final FileRef file;

  @override
  State<AudioViewer> createState() => _AudioViewerState();
}

class _AudioViewerState extends State<AudioViewer> {
  final AudioPlayer _player = AudioPlayer();
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setFilePath(widget.file.path);
    } catch (_) {
      if (mounted) setState(() => _errored = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: _errored
          ? const _MediaError(kind: 'audio')
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.audiotrack, size: 72),
                  const SizedBox(height: 24),
                  StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = _player.duration ?? Duration.zero;
                      final max = dur.inMilliseconds.toDouble();
                      final value = pos.inMilliseconds
                          .clamp(0, max <= 0 ? 0 : max.toInt())
                          .toDouble();
                      return Column(
                        children: <Widget>[
                          Slider(
                            min: 0,
                            max: max <= 0 ? 1 : max,
                            value: max <= 0 ? 0 : value,
                            onChanged: max <= 0
                                ? null
                                : (v) => _player
                                    .seek(Duration(milliseconds: v.toInt())),
                          ),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(_fmt(pos)),
                              Text(_fmt(dur)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snap) {
                      final playing = snap.data?.playing ?? false;
                      return IconButton.filled(
                        iconSize: 48,
                        icon: Icon(playing
                            ? Icons.pause
                            : Icons.play_arrow),
                        onPressed: () =>
                            playing ? _player.pause() : _player.play(),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

/// Shared graceful media error state.
class _MediaError extends StatelessWidget {
  const _MediaError({required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text("Can't play this $kind",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('The format may not be supported on this device.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
