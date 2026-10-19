import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
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

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: _errored
          ? const ViewerError(
              title: "Can't play this audio",
              hint: 'The format may not be supported on this device.')
          : Column(
              children: <Widget>[
                const Expanded(
                  child: Center(child: Icon(Icons.audiotrack, size: 96)),
                ),
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnap) {
                    return StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, stateSnap) {
                        return TransportBar(
                          playing: stateSnap.data?.playing ?? false,
                          position: posSnap.data ?? Duration.zero,
                          duration: _player.duration ?? Duration.zero,
                          onPlayPause: () => (stateSnap.data?.playing ?? false)
                              ? _player.pause()
                              : _player.play(),
                          onSeek: _player.seek,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }
}
