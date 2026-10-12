import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';

class DeviceFingerprintService {
  static const _androidId = AndroidId();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getRawDeviceId() async {
    if (Platform.isAndroid) {
      try {
        final id = await _androidId.getId();
        if (id != null && id.trim().isNotEmpty) {
          return 'android:$id';
        }
      } catch (_) {}
      final info = await _deviceInfo.androidInfo;
      return 'android:${info.fingerprint}|${info.model}|${info.manufacturer}|${info.id}';
    }

    if (Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      return 'windows:${info.deviceId}|${info.productId}|${info.computerName}';
    }

    if (Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      return 'linux:${info.machineId}|${info.id}|${info.machineId}';
    }

    if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      return 'macos:${info.systemGUID}|${info.model}';
    }

    return 'unknown:${ui.PlatformDispatcher.instance.locale}';
  }

  Future<String> getFingerprint() async {
    final raw = await getRawDeviceId();
    final digest = crypto.sha256.convert(utf8.encode(raw));
    return digest.toString().toUpperCase();
  }
}
