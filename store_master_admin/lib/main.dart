import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/license_manager_screen.dart';
import 'widgets/video_store_splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade900,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${details.exceptionAsString()}\n${details.stack ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  };

  runApp(const LicenseManagerApp());
}

class LicenseManagerApp extends StatelessWidget {
  const LicenseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StoreMaster License Manager',
      locale: const Locale('fa', 'IR'),
      supportedLocales: const <Locale>[Locale('fa', 'IR')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
      ),
      home: const _AppStartup(),
    );
  }
}

class _AppStartup extends StatefulWidget {
  const _AppStartup();

  @override
  State<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<_AppStartup> {
  bool _showSplash = true;

  void _finishSplash() {
    if (!mounted || !_showSplash) return;

    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previous,
            if (current != null) current,
          ],
        );
      },
      child: _showSplash
          ? VideoStoreSplash(
              key: const ValueKey('license-video-splash'),
              onFinished: _finishSplash,
            )
          : const LicenseManagerScreen(
              key: ValueKey('license-manager'),
            ),
    );
  }
}
