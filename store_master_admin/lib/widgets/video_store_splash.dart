import 'dart:async';
import 'dart:io';

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
  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _finishing = false;
  bool _initializing = true;
  double _opacity = 1.0;
  String? _error;

  List<String> get _assetCandidates {
    if (Platform.isWindows) {
      return const <String>[
        'assets/videos/splash_windows.mp4',
        'assets/videos/splash.mp4',
      ];
    }
    return const <String>[
      'assets/videos/splash.mp4',
    ];
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    Object? lastError;

    for (final asset in _assetCandidates) {
      VideoPlayerController? candidate;
      try {
        candidate = VideoPlayerController.asset(asset);
        await candidate.initialize();

        if (!mounted) {
          await candidate.dispose();
          return;
        }

        _controller = candidate;
        setState(() {
          _initializing = false;
          _error = null;
        });

        await candidate.setLooping(false);
        await candidate.play();
        candidate.addListener(_videoListener);

        final duration = candidate.value.duration;
        _fallbackTimer = Timer(
          duration > Duration.zero
              ? duration + const Duration(seconds: 3)
              : const Duration(seconds: 15),
          _finish,
        );
        return;
      } catch (e) {
        lastError = e;
        await candidate?.dispose();
        _controller = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _initializing = false;
      _error = lastError?.toString() ?? 'ویدیوی Splash قابل پخش نیست.';
    });

    _fallbackTimer = Timer(
      const Duration(milliseconds: 700),
      _finish,
    );
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _finishing) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;

    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 1500)) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing || !mounted) return;

    _finishing = true;
    _fallbackTimer?.cancel();

    // Let AnimatedSwitcher replace the splash without leaving a fully
    // transparent frame on Android.
    if (mounted) {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Center(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            else
              const ColoredBox(color: Colors.black),
            if (_initializing)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            if (_error != null && !ready)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }
}
