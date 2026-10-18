import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/file_ref.dart';
import '../viewer_scaffold.dart';

/// Video player: play/pause + a progress bar, via `video_player`. Shows a
/// graceful error state on init failure or a codec the device can't decode
/// (e.g. some `.mkv`). Disposes the controller.
///
/// Playback uses the platform engine (ExoPlayer on Android) and is verified
/// on-device; the controls + error state are the logic under test.
class VideoViewer extends StatefulWidget {
  const VideoViewer({super.key, required this.file});

  final FileRef file;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.file.path));
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      if (_controller.value.hasError) {
        setState(() => _errored = true);
      } else {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (mounted) setState(() => _errored = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      title: widget.file.name,
      child: _errored
          ? const _MediaError(kind: 'video')
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => IconButton.filled(
                          iconSize: 40,
                          icon: Icon(value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow),
                          onPressed: () => value.isPlaying
                              ? _controller.pause()
                              : _controller.play(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

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
