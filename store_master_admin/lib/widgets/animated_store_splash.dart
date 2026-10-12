import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoStoreSplash extends StatefulWidget {
  const VideoStoreSplash({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<VideoStoreSplash> createState() => _VideoStoreSplashState();
}

class _VideoStoreSplashState extends State<VideoStoreSplash> {
  late VideoPlayerController _controller;

  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/videos/splash.mp4',
    );

    _controller.initialize().then((_) {
      if (!mounted) return;

      setState(() {});

      _controller.play();
    });

    _controller.addListener(() {
      if (!_controller.value.isInitialized) {
        return;
      }

      if (_controller.value.position >= _controller.value.duration &&
          !_finished) {
        _finished = true;

        widget.onFinished();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(
              _controller,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }
}
