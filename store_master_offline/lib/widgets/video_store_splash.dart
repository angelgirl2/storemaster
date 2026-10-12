import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  bool _finished = false;
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _initializing = false;
  double _opacity = 1.0;

  String get _assetPath {
    if (!kIsWeb && Platform.isWindows) {
      return 'assets/videos/splash_windows2.mp4';
    }
    return 'assets/videos/splash_android.mp4';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializeVideo());
  }

  Future<void> _initializeVideo() async {
    if (_initializing || _finished || !mounted) return;
    _initializing = true;

    final previous = _controller;
    _controller = null;
    previous?.removeListener(_onVideoChanged);
    await previous?.dispose();

    if (mounted) {
      setState(() {
        _videoReady = false;
        _videoFailed = false;
      });
    }

    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.asset(_assetPath);
      _controller = controller;
      controller.addListener(_onVideoChanged);

      // Windows media initialization can take several seconds on first startup.
      // Keep a bounded timeout so a broken decoder/asset cannot deadlock startup.
      await controller.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Splash video initialization timed out after 20 seconds',
        ),
      );

      if (!mounted || _finished || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(false);
      await controller.setVolume(0.0);

      if (!mounted || _finished || !identical(_controller, controller)) {
        return;
      }

      setState(() {
        _videoReady = true;
        _videoFailed = false;
      });

      await controller.play();

      // Safety timeout: if the native backend never reports completion,
      // never trap the application behind the splash.
      _startFallbackTimer(const Duration(seconds: 15));
    } catch (e, stack) {
      debugPrint('Splash video unavailable: $e\n$stack');

      if (identical(_controller, controller)) {
        _controller?.removeListener(_onVideoChanged);
        _controller = null;
      }

      try {
        await controller?.dispose();
      } catch (_) {}

      if (mounted && !_finished) {
        setState(() {
          _videoReady = false;
          _videoFailed = true;
        });
        // Recovery path only: the requested video splash remains the primary
        // startup UI, but a decoder/asset failure must never deadlock startup.
        _startFallbackTimer(const Duration(milliseconds: 1200));
      }
    } finally {
      _initializing = false;
    }
  }

  void _startFallbackTimer(Duration duration) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(duration, _finish);
  }

  void _onVideoChanged() {
    final controller = _controller;
    if (!mounted || _finished || controller == null) return;

    final value = controller.value;
    if (!value.isInitialized) return;

    final duration = value.duration;
    if (duration <= Duration.zero) return;

    if (value.isCompleted) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _fallbackTimer?.cancel();

    // Tell the parent immediately. The parent swaps this widget for AppShell
    // when startup is ready, preventing an intermediate transparent/black
    // frame on Android.
    if (mounted) {
      widget.onFinished();
    }

    // Dispose after the parent has had a chance to rebuild.
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      final c = _controller;
      _controller = null;
      c?.removeListener(_onVideoChanged);
      if (c != null) {
        unawaited(c.dispose());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return ColoredBox(
      color: Colors.black,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady && controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else
              _FallbackSplash(
                failed: _videoFailed,
                retrying: _initializing && _videoFailed,
                onRetry: _videoFailed ? () => unawaited(_initializeVideo()) : null,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _finished = true;
    _fallbackTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onVideoChanged);
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }
}

class _FallbackSplash extends StatelessWidget {
  const _FallbackSplash({
    required this.failed,
    required this.retrying,
    this.onRetry,
  });

  final bool failed;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.storefront_rounded,
                size: 120,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'StoreMaster',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (failed) ...[
              const SizedBox(height: 12),
              const Text(
                'در حال آماده‌سازی برنامه…',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (onRetry != null && !retrying) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('تلاش دوباره'),
                ),
              ],
            ],
            const SizedBox(height: 18),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
