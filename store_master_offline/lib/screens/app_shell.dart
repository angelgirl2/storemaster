import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_config.dart';
import '../models/user.dart';
import '../services/license/license_service.dart';
import '../viewmodels/main_viewmodel.dart';

import 'dashboard_screen.dart';
import 'license/license_activation_screen.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Timer? _licenseTimer;
  LicenseStatus? _licenseStatus;
  bool _licenseChecked = false;
  bool _licenseCheckRunning = false;

  late final MainViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<MainViewModel>();
    _refreshLicense(initial: true);
    // Periodic local license validation must not replace the visible page
    // with a spinner. A previously valid status remains visible while a
    // background check is running.
    _licenseTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshLicense();
    });
  }

  Future<void> _refreshLicense({bool initial = false}) async {
    final cfg = _viewModel.config;
    if (!mounted || cfg == null || !cfg.isConfigured) return;
    if (_licenseCheckRunning) return;

    _licenseCheckRunning = true;
    if (initial && !_licenseChecked && mounted) {
      setState(() {});
    }

    try {
      final status = await LicenseService.instance.validate(config: cfg);
      if (!mounted) return;
      setState(() {
        _licenseStatus = status;
        _licenseChecked = true;
      });
    } catch (e) {
      if (!mounted) return;
      // Do not eject a currently valid local session because of a transient
      // validation error. Only the very first check may show activation.
      setState(() {
        _licenseChecked = true;
        if (_licenseStatus == null) {
          _licenseStatus = const LicenseStatus(valid: false, message: 'لایسنس قابل بررسی نیست');
        }
      });
    } finally {
      _licenseCheckRunning = false;
    }
  }

  @override
  void dispose() {
    _licenseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppShell only depends on authentication/config state. Data changes in
    // SQLite must be consumed by the active screen, not rebuild the entire
    // navigation shell.
    final config = context.select<MainViewModel, StoreConfig?>(
      (vm) => vm.config,
    );
    final currentUser = context.select<MainViewModel, User?>(
      (vm) => vm.currentUser,
    );

    if (config == null || !config.isConfigured) {
      return const SetupScreen();
    }

    final status = _licenseStatus;
    if (!_licenseChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (status == null || !status.valid) {
      return const LicenseActivationScreen();
    }

    if (currentUser == null) {
      return const LoginScreen();
    }

    // Keep the active dashboard subtree alive. Child screens listen directly
    // to MainViewModel and update only when their data actually changes.
    return const DashboardScreen();
  }
}
