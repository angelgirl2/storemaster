// StoreMaster bootstrap
// Video splash + offline database

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'database/database_helper.dart';
import 'screens/app_shell.dart';
import 'theme/store_theme.dart';
import 'viewmodels/main_viewmodel.dart';
import 'services/local_network_sync_service.dart';
import 'services/online_api_service.dart';
import 'services/cloud_sync_service.dart';
import 'widgets/video_store_splash.dart';

Future<void> _prepareStoreMaster() async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // SQLite is required before the main shell can render, but LAN discovery
  // must never be allowed to block Android startup.
  await DatabaseHelper.instance.database.timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw TimeoutException(
      'پایگاه داده در مهلت ۱۵ ثانیه آماده نشد.',
    ),
  );

  // Restore the saved cloud session before screens attempt invoice sharing or
  // periodic synchronization. If the API is unavailable, local work continues.
  try {
    await OnlineApiService.instance.initialize();
    if (OnlineApiService.onlineEnabled) {
      CloudSyncService.instance.startPeriodic();
    }
  } catch (e) {
    debugPrint('Cloud session restore skipped; continuing offline: $e');
  }

  try {
    await LocalNetworkSyncService.instance.start().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint('LAN sync startup timed out; continuing without LAN sync.');
      },
    );
  } catch (e, stack) {
    debugPrint('LAN sync startup skipped: $e\n$stack');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The StoreMaster startup splash is video-based on desktop and mobile.
  // The media_kit backend must be initialized for Windows as well.
  if (!kIsWeb) {
    VideoPlayerMediaKit.ensureInitialized(
      windows: Platform.isWindows,
    );
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('Flutter build/render error: ${details.exceptionAsString()}');
    return const ColoredBox(
      color: Color(0xff8b0000),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'خطا در نمایش رابط کاربری',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  };

  runApp(const StoreMasterBootstrap());
}

class StoreMasterBootstrap extends StatefulWidget {
  const StoreMasterBootstrap({super.key});

  @override
  State<StoreMasterBootstrap> createState() => _StoreMasterBootstrapState();
}

class _StoreMasterBootstrapState extends State<StoreMasterBootstrap> {
  late final MainViewModel _viewModel;

  Object? _error;
  bool _ready = false;
  bool _splashFinished = false;

  @override
  void initState() {
    super.initState();
    _viewModel = MainViewModel();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _prepareStoreMaster().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'راه‌اندازی اولیه برنامه در مهلت ۲۰ ثانیه کامل نشد.',
        ),
      );
      await _viewModel.loadAll(showLoading: false).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'بارگذاری اطلاعات در مهلت ۲۰ ثانیه کامل نشد.',
        ),
      );

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e, stack) {
      debugPrint('Startup error: $e\n$stack');
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _finishSplash() {
    if (!mounted || _splashFinished) return;
    setState(() => _splashFinished = true);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider must exist above the MaterialApp so the same MainViewModel
    // instance is used after the splash and inside AppShell.
    return ChangeNotifierProvider<MainViewModel>.value(
      value: _viewModel,
      child: StoreMasterApp(
        ready: _ready,
        splashFinished: _splashFinished,
        error: _error,
        onSplashFinished: _finishSplash,
      ),
    );
  }
}

class StoreMasterApp extends StatelessWidget {
  const StoreMasterApp({
    super.key,
    required this.ready,
    required this.splashFinished,
    required this.error,
    required this.onSplashFinished,
  });

  final bool ready;
  final bool splashFinished;
  final Object? error;
  final VoidCallback onSplashFinished;

  @override
  Widget build(BuildContext context) {
    // Only settings that genuinely affect MaterialApp are selected here.
    // Database/data notifications must not rebuild the entire application
    // root or recreate navigation/screen subtrees.
    final themeName = context.select<MainViewModel, String>(
      (vm) => vm.config?.colorTheme ?? 'PROFESSIONAL',
    );
    final dark = context.select<MainViewModel, bool>(
      (vm) => vm.config?.isDarkMode ?? false,
    );

    Widget home;

    if (error != null) {
      home = _StartupError(error: error!);
    } else if (!ready) {
      // Never keep a completed/faded-out splash mounted while startup work is
      // still running. That state previously produced a permanent black page
      // on Android when DB initialization or a startup service was delayed.
      home = _StartupLoading(
        splashFinished: splashFinished,
      );
    } else if (!splashFinished) {
      home = VideoStoreSplash(
        key: const ValueKey('storemaster-video-splash'),
        onFinished: onSplashFinished,
      );
    } else {
      home = const AppShell(
        key: ValueKey('storemaster-app-shell'),
      );
    }

    return MaterialApp(
      title: 'StoreMaster',
      debugShowCheckedModeBanner: false,
      theme: StoreTheme.buildTheme(
        themeName: themeName,
        darkTheme: false,
      ),
      darkTheme: StoreTheme.buildTheme(
        themeName: themeName,
        darkTheme: true,
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fa', 'IR'),
      ],
      locale: const Locale('fa', 'IR'),
      scrollBehavior: const _StoreScrollBehavior(),
      builder: (context, child) {
        return Directionality(
          textDirection: ui.TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    );
  }
}

class _StoreScrollBehavior extends MaterialScrollBehavior {
  const _StoreScrollBehavior();

  @override
  Set<ui.PointerDeviceKind> get dragDevices => <ui.PointerDeviceKind>{
    ui.PointerDeviceKind.touch,
    ui.PointerDeviceKind.mouse,
    ui.PointerDeviceKind.stylus,
    ui.PointerDeviceKind.trackpad,
  };
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading({
    required this.splashFinished,
  });

  final bool splashFinished;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff090611),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 18),
            Text(
              splashFinished
                  ? 'در حال آماده‌سازی StoreMaster…'
                  : 'در حال راه‌اندازی StoreMaster…',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff090611),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            'خطا در راه‌اندازی\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}
