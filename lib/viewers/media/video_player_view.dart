import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/file_ref.dart';
import '../viewer_common.dart';
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
          ? const ViewerError(
              title: "Can't play this video",
              hint: 'The format may not be supported on this device.')
          : !_ready
              ? const ViewerLoading()
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
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => TransportBar(
                        playing: value.isPlaying,
                        position: value.position,
                        duration: value.duration,
                        onPlayPause: () => value.isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                        onSeek: _controller.seekTo,
                      ),
                    ),
                  ],
                ),
    );
  }
}
