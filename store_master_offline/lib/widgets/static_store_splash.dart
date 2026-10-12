// static_store_splash.dart
// اسپلش استاتیک امن برای ویندوز/لینوکس/مک:
// ویدیوپلیر در دسکتاپ هنگام رفتن برنامه به پس‌زمینه،
// خطاهای «Stack Overflow» و «child._parent == this» تولید می‌کند؛
// به همین دلیل روی دسکتاپ به‌جای ویدیو از این صفحه استفاده می‌شود.

import 'package:flutter/material.dart';

class StaticStoreSplash extends StatefulWidget {
  const StaticStoreSplash({super.key});

  @override
  State<StaticStoreSplash> createState() => _StaticStoreSplashState();
}

class _StaticStoreSplashState extends State<StaticStoreSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff090611),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.storefront,
                    size: 110,
                    color: Colors.amber.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'StoreMaster',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
