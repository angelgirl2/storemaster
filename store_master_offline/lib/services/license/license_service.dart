import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/database_helper.dart';
import '../../models/store_config.dart';
import 'device_fingerprint_service.dart';
import 'license_crypto.dart';
import 'license_models.dart';
import '../online_api_service.dart';
import '../online_config.dart';
import '../online_session_store.dart';

class LicenseStatus {
  final bool valid;
  final String message;
  final LicensePayload? payload;
  final int remainingDays;

  const LicenseStatus({
    required this.valid,
    required this.message,
    this.payload,
    this.remainingDays = 0,
  });
}

class LicenseService {
  static final LicenseService instance =
      LicenseService._();

  LicenseService._();

  final DeviceFingerprintService _device =
      DeviceFingerprintService();

  final DatabaseHelper _db =
      DatabaseHelper.instance;

  static const String _payloadKey =
      'license_payload';

  static const String _signatureKey =
      'license_signature';

  static const String _clockKey =
      'license_last_clock';

  static const String _trialKey = 'local_trial_payload';
  static const String _expiredLatchKey = 'license_expired_latched';
  static const String _revokedIdsKey = 'license_revoked_ids_v1';
  static const String _revocationIssuedAtKey = 'license_revocation_issued_at_v1';

  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _installSecretKey = 'license_install_secret_v2';
  static const String _installBindingKey = 'license_install_binding_v2';
  static const String _acceptedIssuedAtKey = 'license_accepted_issued_at_v2';
  static const String _acceptedLicenseIdKey = 'license_accepted_id_v2';
  static const String _secureTrialKey = 'license_trial_secure_v2';

  // یک کپی دوم خارج از SQLite برای تشخیص عقب‌کشیدن ساعت یا حذف/بازنویسی
  // ساده‌ی دیتابیس. این مکانیزم ضد دستکاری مطلق نیست؛ در حالت آفلاین هیچ
  // روش کلاینتی نمی‌تواند در برابر حذف کامل داده‌های برنامه مصونیت 100٪ بدهد.
  static const String _clockSentinelFileName = 'license_clock_guard.json';
  static const String _clockGuardKey =
      'StoreMaster-license-clock-guard-v1-local-tamper-evident';

  Future<String> getDeviceId() =>
      _device.getFingerprint();

  Future<Map<String, String>> _readLicenseSettings(
    Database db,
  ) async {
    final rows = await db.query(
      'app_settings',
      columns: const ['key', 'value'],
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: const [
        _payloadKey,
        _signatureKey,
        _clockKey,
        _expiredLatchKey,
      ],
    );

    return <String, String>{
      for (final row in rows)
        '${row['key']}': '${row['value'] ?? ''}',
    };
  }


  Future<File> _clockSentinelFile() async {
    final dir = await getApplicationSupportDirectory();
    final storeDir = Directory(
      '${dir.path}${Platform.pathSeparator}StoreMaster',
    );
    await storeDir.create(recursive: true);
    return File(
      '${storeDir.path}${Platform.pathSeparator}$_clockSentinelFileName',
    );
  }

  Future<String> _clockDigest(int value) async {
    final secret = await _ensureInstallSecret();
    final mac = crypto.Hmac(
      crypto.sha256,
      utf8.encode('$secret|$_clockGuardKey'),
    );
    return mac.convert(utf8.encode('$value')).toString();
  }

  Future<int> _readClockSentinel() async {
    try {
      final file = await _clockSentinelFile();
      if (!await file.exists()) return 0;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return 0;
      final value = int.tryParse('${raw['lastWallClock'] ?? ''}') ?? 0;
      final digest = '${raw['digest'] ?? ''}';
      if (value <= 0 || digest.isEmpty || digest != await _clockDigest(value)) {
        // فایل دستکاری/خراب شده است؛ مقدار آن را معتبر فرض نمی‌کنیم.
        return 0;
      }
      return value;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _writeClockSentinel(int value) async {
    try {
      final file = await _clockSentinelFile();
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'version': 2,
          'lastWallClock': value,
          'digest': await _clockDigest(value),
        }),
        flush: true,
      );
    } catch (_) {
      // نبودن فایل نگهبان نباید باعث خرابی عملیات عادی برنامه شود؛
      // مقدار SQLite همچنان نگهدارنده‌ی اصلی وضعیت است.
    }
  }

  Future<void> _recordClock(Database db, int now) async {
    await db.insert(
      'app_settings',
      {
        'key': _clockKey,
        'value': '$now',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _writeClockSentinel(now);
  }

  Future<bool> _clockWasRolledBack(
    Map<String, String> dbMap,
    int now,
  ) async {
    final dbClock = int.tryParse(dbMap[_clockKey] ?? '') ?? 0;
    final fileClock = await _readClockSentinel();
    final trustedLast = [dbClock, fileClock].reduce(
      (a, b) => a > b ? a : b,
    );
    return trustedLast > 0 &&
        now + const Duration(minutes: 5).inMilliseconds < trustedLast;
  }

  Future<Set<String>> _readSecureRevokedIds() async {
    try {
      final raw = await _secureStorage.read(key: _revokedIdsKey);
      if (raw == null || raw.trim().isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<int> _readSecureRevocationIssuedAt() async {
    try {
      return int.tryParse(await _secureStorage.read(key: _revocationIssuedAtKey) ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _writeSecureRevocations(Set<String> ids, int issuedAt) async {
    final normalized = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();
    await _secureStorage.write(key: _revokedIdsKey, value: jsonEncode(normalized));
    if (issuedAt > 0) {
      await _secureStorage.write(key: _revocationIssuedAtKey, value: '$issuedAt');
    }
  }

  Future<bool> _isLocallyRevoked(String licenseId) async {
    final ids = await _readSecureRevokedIds();
    return ids.contains(licenseId.trim());
  }

  /// اعمال بسته ابطال آفلاین امضاشده‌ای که از License Manager منتقل شده است.
  /// بسته جدید فقط به فهرست ابطال اضافه می‌کند و هرگز مورد قبلی را حذف نمی‌کند.
  Future<int> importOfflineRevocationPackage(String sourceText) async {
    final decoded = jsonDecode(sourceText);
    if (decoded is! Map) throw const FormatException('ساختار بسته ابطال نامعتبر است.');
    final map = Map<String, dynamic>.from(decoded);
    final payloadRaw = map['payload'];
    final signature = '${map['signature'] ?? ''}'.trim();
    if (payloadRaw is! Map || signature.isEmpty) {
      throw const FormatException('بسته ابطال ناقص است.');
    }
    final payload = Map<String, dynamic>.from(payloadRaw);
    if ('${payload['schema'] ?? ''}' != 'StoreMaster.Revocations.v1') {
      throw const FormatException('نسخه بسته ابطال پشتیبانی نمی‌شود.');
    }
    final canonical = jsonEncode(payload);
    if (!await LicenseCrypto.verify(canonical, signature)) {
      throw const FormatException('امضای بسته ابطال معتبر نیست.');
    }
    final issuedAt = (payload['generatedAt'] as num?)?.toInt() ?? 0;
    if (issuedAt <= 0) throw const FormatException('تاریخ بسته ابطال معتبر نیست.');
    final previousIssuedAt = await _readSecureRevocationIssuedAt();
    final previousIds = await _readSecureRevokedIds();
    if (issuedAt < previousIssuedAt) {
      // نسخه قدیمی را قبول می‌کنیم فقط برای استخراج شناسه‌های جدید؛ هرگز
      // فهرست قبلی را جایگزین نمی‌کنیم. بدین ترتیب بسته قدیمی نمی‌تواند لغو قبلی را برگرداند.
      return 0;
    }
    // License Managerهای مختلف ممکن است شناسه را با نام‌های متفاوت صادر کنند.
    // همهٔ شکل‌های شناخته‌شده را می‌پذیریم تا بسته معتبر به «۰ لایسنس» ختم نشود.
    dynamic rawItems = payload['items'] ?? payload['licenses'] ?? payload['revokedLicenses'] ?? payload['licenseIds'];
    if (rawItems is! List) {
      throw const FormatException('فهرست ابطال داخل بسته معتبر نیست.');
    }

    String extractLicenseId(dynamic item) {
      if (item is String || item is num) return '$item'.trim();
      if (item is! Map) return '';
      final direct = [
        item['licenseId'],
        item['licenseKey'],
        item['key'],
        item['id'],
        item['code'],
      ];
      for (final value in direct) {
        final text = '${value ?? ''}'.trim();
        if (text.isNotEmpty) return text;
      }
      final nested = item['license'] ?? item['payload'];
      if (nested is Map) return extractLicenseId(nested);
      return '';
    }

    final merged = <String>{...previousIds};
    for (final item in rawItems) {
      final id = extractLicenseId(item);
      if (id.isNotEmpty) merged.add(id);
    }
    final added = merged.length - previousIds.length;
    await _writeSecureRevocations(merged, issuedAt);

    final current = await _db.database;
    bool currentLicenseRevoked = false;
    final activeRows = await current.query(
      'app_settings',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const [_payloadKey],
      limit: 1,
    );
    if (activeRows.isNotEmpty) {
      final activeJson = '${activeRows.first['value'] ?? ''}';
      try {
        final active = LicensePayload.fromMap(
          Map<String, dynamic>.from(jsonDecode(activeJson) as Map),
        );
        currentLicenseRevoked = merged.contains(active.licenseId.trim());
        if (currentLicenseRevoked) {
          // فقط مجوز جاری را از app_settings جدا می‌کنیم؛ هیچ جدول تجاری
          // یا دادهٔ فروشگاه حذف نمی‌شود.
          await current.transaction((txn) async {
            await txn.delete(
              'app_settings',
              where: 'key IN (?, ?)',
              whereArgs: const [_payloadKey, _signatureKey],
            );
            await txn.insert(
              'app_settings',
              {'key': _expiredLatchKey, 'value': '1'},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          });
        }
      } catch (_) {}
    }

    // اگر بسته فقط همان لایسنس فعلی را داشت و قبلاً در فهرست ثبت شده بود،
    // تعداد «لایسنس جدید» صفر است اما ابطال فعلی همچنان باید اعمال شود.
    if (currentLicenseRevoked && added == 0) return 1;
    return added;
  }


  String _randomSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _installationBinding(String licenseId, String deviceId, String secret) {
    final mac = crypto.Hmac(
      crypto.sha256,
      utf8.encode(secret),
    );
    return mac.convert(utf8.encode('$licenseId|$deviceId')).toString();
  }

  Future<String> _ensureInstallSecret() async {
    final existing = await _secureStorage.read(key: _installSecretKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final secret = _randomSecret();
    await _secureStorage.write(key: _installSecretKey, value: secret);
    return secret;
  }

  Future<void> _enrollSecureBinding(LicensePayload payload) async {
    final deviceId = await getDeviceId();
    final secret = await _ensureInstallSecret();
    final binding = _installationBinding(payload.licenseId, deviceId, secret);
    await _secureStorage.write(key: _installBindingKey, value: binding);
    await _secureStorage.write(
      key: _acceptedLicenseIdKey,
      value: payload.licenseId,
    );
    await _secureStorage.write(
      key: _acceptedIssuedAtKey,
      value: '${payload.issuedAt}',
    );
  }

  Future<bool> _secureBindingMatches(LicensePayload payload) async {
    try {
      final storedBinding = await _secureStorage.read(key: _installBindingKey);
      if (storedBinding == null || storedBinding.trim().isEmpty) return false;
      final secret = await _secureStorage.read(key: _installSecretKey);
      if (secret == null || secret.trim().isEmpty) return false;
      final deviceId = await getDeviceId();
      return storedBinding ==
          _installationBinding(payload.licenseId, deviceId, secret);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _acceptedLicenseCanBeReplaced(LicensePayload next) async {
    try {
      final acceptedId = (await _secureStorage.read(key: _acceptedLicenseIdKey) ?? '').trim();
      final acceptedIssuedAt = int.tryParse(
            await _secureStorage.read(key: _acceptedIssuedAtKey) ?? '',
          ) ??
          0;
      if (acceptedIssuedAt <= 0 || acceptedId.isEmpty) return true;
      if (next.licenseId == acceptedId) return true;
      // Never allow an older signed license to replace a newer accepted one.
      return next.issuedAt >= acceptedIssuedAt;
    } catch (_) {
      return true;
    }
  }

  Future<void> _activateSecureTrialIfNeeded({
    required String deviceId,
    required int issuedAt,
    required int expiresAt,
  }) async {
    final existing = await _secureStorage.read(key: _secureTrialKey);
    if (existing != null && existing.trim().isNotEmpty) return;
    final secret = await _ensureInstallSecret();
    final data = jsonEncode(<String, dynamic>{
      'deviceId': deviceId,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'binding': _installationBinding('TRIAL', deviceId, secret),
    });
    await _secureStorage.write(key: _secureTrialKey, value: data);
  }

  Future<Map<String, dynamic>?> _readSecureTrial() async {
    try {
      final raw = await _secureStorage.read(key: _secureTrialKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _secureTrialValid({required String deviceId, required int now}) async {
    final trial = await _readSecureTrial();
    if (trial == null) return true;
    final storedDevice = '${trial['deviceId'] ?? ''}'.trim().toUpperCase();
    final expiresAt = (trial['expiresAt'] as num?)?.toInt() ?? 0;
    final issuedAt = (trial['issuedAt'] as num?)?.toInt() ?? 0;
    final secret = await _secureStorage.read(key: _installSecretKey);
    if (storedDevice.isEmpty || secret == null || issuedAt <= 0 || expiresAt <= issuedAt) {
      return false;
    }
    final expected = _installationBinding('TRIAL', storedDevice, secret);
    if ('${trial['binding'] ?? ''}' != expected) return false;
    if (storedDevice != deviceId.trim().toUpperCase()) return false;
    return now < expiresAt;
  }

  String _currentPlatform() {
    if (Platform.isAndroid) {
      return 'ANDROID';
    }

    if (Platform.isWindows) {
      return 'WINDOWS';
    }

    return Platform.operatingSystem
        .toUpperCase();
  }


  Future<int> _trustedNowMillis() async {
    final localNow = DateTime.now().millisecondsSinceEpoch;
    if (!OnlineApiService.onlineEnabled) return localNow;
    try {
      return await OnlineApiService.instance.serverTimeMillis();
    } catch (_) {
      if (OnlineConfig.instance.required) rethrow;
      return localNow;
    }
  }

  Set<String> _businessTypes(
    StoreConfig? config,
  ) {
    if (config == null) {
      return <String>{};
    }

    return config.storeType
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  bool _businessMatches(
    StoreConfig? config,
    List<String> licensedTypes,
  ) {
    if (config == null) {
      return true;
    }

    final currentTypes = _businessTypes(config);
    final licensed =
        licensedTypes.toSet();

    if (licensed.contains('*')) {
      return true;
    }

    if (currentTypes.isEmpty) {
      return false;
    }

    return currentTypes
        .every(licensed.contains);
  }

  Future<void> activateLocalTrial({
    required String licenseId,
    required List<String> features,
    required List<String> businessTypes,
    required int expiresAt,
  }) async {
    final db = await _db.database;

    // دوره آزمایشی روی همان نصب فقط یک بار ساخته می‌شود.
    final existing = await _readLocalTrial(db);
    if (existing != null) {
      throw StateError('دوره آزمایشی این نصب قبلاً فعال شده است.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final deviceId = await getDeviceId();
    final payload = <String, dynamic>{
      'licenseId': licenseId,
      'plan': 'TRIAL',
      'durationDays': 15,
      'deviceId': deviceId,
      'issuedAt': expiresAt - const Duration(days:15).inMilliseconds,
      'expiresAt': expiresAt,
      'features': [...features]..sort(),
      'businessTypes': [...businessTypes]..sort(),
    };
    await db.insert(
      'app_settings',
      {
        'key': _trialKey,
        'value': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // اولین زمان معتبر را قبل از هر استفاده‌ی بعدی ثبت می‌کنیم تا
    // عقب‌کشیدن ساعت بلافاصله بعد از فعال‌سازی دوره آزمایشی بی‌اثر شود.
    await _recordClock(db, now);
    await _activateSecureTrialIfNeeded(
      deviceId: deviceId,
      issuedAt: payload['issuedAt'] as int,
      expiresAt: expiresAt,
    );
  }

  Future<Map<String, dynamic>?> _readLocalTrial(Database db) async {
    final rows = await db.query('app_settings', columns: const ['value'], where: 'key = ?', whereArgs: const [_trialKey], limit: 1);
    if (rows.isEmpty) return null;
    try {
      final raw = jsonDecode('${rows.first['value'] ?? ''}');
      return raw is Map ? Map<String, dynamic>.from(raw) : null;
    } catch (_) {
      return null;
    }
  }

  Future<LicenseStatus> validate({
    StoreConfig? config,
  }) async {
    try {
      final db = await _db.database;
      final map = await _readLicenseSettings(db);
      var latchedExpired = (map[_expiredLatchKey] ?? '') == '1';
      // An online-session license can be renewed remotely under the same ID.
      // If its local expiry was latched earlier, ask the authoritative server
      // before keeping the app locked. Signed offline license files still need
      // their renewed license document activated locally.
      if (latchedExpired &&
          (map[_payloadKey] ?? '').trim().isEmpty &&
          OnlineApiService.onlineEnabled) {
        final session = await OnlineSessionStore.instance.read();
        final licenseId = '${session['licenseId'] ?? ''}'.trim();
        if (licenseId.isNotEmpty) {
          try {
            final deviceId = await getDeviceId();
            final remote = await OnlineApiService.instance.publicLicenseValidate(
              licenseId: licenseId,
              deviceId: deviceId,
            );
            final remoteExpiry = (remote['licenseExpiresAt'] as num?)?.toInt() ?? 0;
            if (remote['valid'] == true &&
                '${remote['status'] ?? 'ACTIVE'}'.toUpperCase() == 'ACTIVE' &&
                remoteExpiry > DateTime.now().millisecondsSinceEpoch) {
              await db.delete(
                'app_settings',
                where: 'key = ?',
                whereArgs: [_expiredLatchKey],
              );
              map.remove(_expiredLatchKey);
              latchedExpired = false;
              await OnlineSessionStore.instance.save({
                ...session,
                'licenseStatus': 'ACTIVE',
                'licenseExpiresAt': remoteExpiry,
                'licensePlan': remote['licensePlan'] ?? session['licensePlan'],
                'features': remote['features'] ?? session['features'] ?? const [],
                'businessTypes': remote['businessTypes'] ?? session['businessTypes'] ?? const [],
              });
            }
          } catch (e) {
            if (e is ApiException && const {401, 403, 404}.contains(e.statusCode)) {
              return LicenseStatus(
                valid: false,
                message: 'لایسنس یا دستگاه از طرف سرور غیرفعال/لغو شده است (${e.statusCode}).',
              );
            }
          }
        }
      }
      if (latchedExpired) {
        return const LicenseStatus(
          valid: false,
          message: 'اعتبار لایسنس قبلاً به پایان رسیده و برنامه قفل شده است.',
        );
      }

      final storedPayloadForRevoke = map[_payloadKey] ?? '';
      if (storedPayloadForRevoke.trim().isNotEmpty) {
        try {
          final active = LicensePayload.fromMap(Map<String, dynamic>.from(jsonDecode(storedPayloadForRevoke) as Map));
          if (await _isLocallyRevoked(active.licenseId)) {
            await db.insert('app_settings', {'key': _expiredLatchKey, 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
            return LicenseStatus(valid: false, message: 'این لایسنس توسط License Manager لغو/تعلیق شده است.', payload: active);
          }
        } catch (_) {}
      }

      // ساعت ویندوز/سیستم مرجع زمان آفلاین است. زمان آخرین بررسی در دیتابیس
      // نگه‌داری می‌شود تا عقب کشیدن ساعت باعث دور زدن اعتبار نشود.
      final wallNow = await _trustedNowMillis();
      if (await _clockWasRolledBack(map, wallNow)) {
        return const LicenseStatus(
          valid: false,
          message:
              'ساعت سیستم به عقب برگشته است. برای جلوگیری از دور زدن لایسنس، '
              'تنظیم خودکار تاریخ و ساعت را فعال کنید.',
        );
      }

      final payloadJson =
          map[_payloadKey] ?? '';
      final signature =
          map[_signatureKey] ?? '';

      if (payloadJson.trim().isEmpty || signature.trim().isEmpty) {
        if ((OnlineConfig.instance.required || !OnlineConfig.instance.baseUrl.contains('YOUR-DOMAIN')) && OnlineApiService.onlineEnabled) {
          final session = await OnlineSessionStore.instance.read();
          final onlineStatus = '${session['licenseStatus'] ?? ''}'.toUpperCase();
          final cachedExpires = (session['licenseExpiresAt'] as num?)?.toInt() ?? 0;
          var effectiveExpires = cachedExpires;
          var onlineFeatures = List<String>.from((session['features'] as List?) ?? const []);
          var onlineBusinessTypes = List<String>.from((session['businessTypes'] as List?) ?? <dynamic>[config?.storeType ?? 'GENERAL']);
          final onlineDevice = await getDeviceId();
          final onlineLicenseId = '${session['licenseId'] ?? ''}'.trim();
          final onlineNow = wallNow;

          if (onlineStatus == 'ACTIVE' && onlineFeatures.isNotEmpty) {
            try {
              // Validate the exact license bound to this session, not merely
              // the newest license belonging to the store.
              final remote = onlineLicenseId.isNotEmpty
                  ? await OnlineApiService.instance.publicLicenseValidate(
                      licenseId: onlineLicenseId,
                      deviceId: onlineDevice,
                    )
                  : await OnlineApiService.instance.licenseStatus();
              final remoteStatus = '${remote['status'] ?? 'ACTIVE'}'.toUpperCase();
              if (remote['valid'] != true || remoteStatus != 'ACTIVE') {
                return LicenseStatus(
                  valid: false,
                  message: 'لایسنس آنلاین توسط سرور فعال نیست: $remoteStatus',
                );
              }
              final serverExpiry = (remote['licenseExpiresAt'] as num?)?.toInt() ?? 0;
              if (serverExpiry > 0) effectiveExpires = serverExpiry;
              final remoteFeatures = remote['features'];
              if (remoteFeatures is List && remoteFeatures.isNotEmpty) {
                onlineFeatures = List<String>.from(remoteFeatures);
              }
              final remoteBusinesses = remote['businessTypes'];
              if (remoteBusinesses is List && remoteBusinesses.isNotEmpty) {
                onlineBusinessTypes = List<String>.from(remoteBusinesses);
              }
              await OnlineSessionStore.instance.save({
                ...session,
                'licenseStatus': 'ACTIVE',
                'licenseExpiresAt': effectiveExpires,
                'licenseId': remote['licenseId'] ?? onlineLicenseId,
                'licensePlan': remote['licensePlan'] ?? session['licensePlan'] ?? 'TRIAL',
                'features': onlineFeatures,
                'businessTypes': onlineBusinessTypes,
              });
            } catch (e) {
              // Explicit authorization/not-found responses are definitive remote
              // rejections. Only connectivity errors may use a cached offline license.
              if (e is ApiException && const {401, 403, 404}.contains(e.statusCode)) {
                return LicenseStatus(
                  valid: false,
                  message: 'دسترسی لایسنس یا این دستگاه توسط سرور رد شد (${e.statusCode}).',
                );
              }
              if (OnlineConfig.instance.required) rethrow;
            }
          }

          if (effectiveExpires > 0 && effectiveExpires <= onlineNow) {
            await db.insert('app_settings', {'key': _expiredLatchKey, 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
            return const LicenseStatus(valid: false, message: 'اعتبار لایسنس آنلاین به پایان رسیده است.');
          }
          if (onlineStatus == 'ACTIVE' && effectiveExpires > onlineNow && onlineFeatures.isNotEmpty) {
            final synthetic = LicensePayload(
              licenseId: onlineLicenseId,
              customerName: '${session['storeName'] ?? ''}',
              phone: '',
              businessTypes: onlineBusinessTypes,
              deviceId: onlineDevice,
              platform: _currentPlatform(),
              plan: '${session['licensePlan'] ?? 'TRIAL'}',
              durationDays: 15,
              issuedAt: effectiveExpires - const Duration(days:15).inMilliseconds,
              expiresAt: effectiveExpires,
              priceAtPurchase: 0,
              currency: config?.currency ?? 'تومان',
              features: onlineFeatures,
            );
            await _recordClock(db, wallNow);
            return LicenseStatus(valid:true, message:'لایسنس آنلاین معتبر است.', payload:synthetic, remainingDays:((effectiveExpires - wallNow) / Duration.millisecondsPerDay).ceil());
          }
        }
        final currentDeviceForTrial = await getDeviceId();
        final secureTrial = await _readSecureTrial();
        if (secureTrial != null) {
          final secureExpires = (secureTrial['expiresAt'] as num?)?.toInt() ?? 0;
          final secureIssued = (secureTrial['issuedAt'] as num?)?.toInt() ?? 0;
          if (secureExpires <= wallNow || secureIssued <= 0 ||
              !await _secureTrialValid(deviceId: currentDeviceForTrial, now: wallNow)) {
            await db.insert('app_settings', {'key': _expiredLatchKey, 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
            return const LicenseStatus(valid: false, message: 'دوره آزمایشی قبلاً استفاده شده یا منقضی شده است.');
          }
        }
        final localTrial = await _readLocalTrial(db);
        if (localTrial != null && '${localTrial['plan'] ?? ''}'.toUpperCase() == 'TRIAL') {
          final trialDevice = '${localTrial['deviceId'] ?? ''}'.trim().toUpperCase();
          final currentDevice = (await getDeviceId()).trim().toUpperCase();
          final trialExpiry = (localTrial['expiresAt'] as num?)?.toInt() ?? 0;
          final trialFeatures = List<String>.from((localTrial['features'] as List?) ?? const []);
          final trialBusinesses = List<String>.from((localTrial['businessTypes'] as List?) ?? const []);
          final trialNow = wallNow;
          if (trialExpiry > 0 && trialExpiry <= trialNow) {
            await db.insert('app_settings', {'key': _expiredLatchKey, 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
            return const LicenseStatus(valid: false, message: 'دوره آزمایشی به پایان رسیده و برنامه قفل شده است.');
          }
          if (trialDevice == currentDevice && trialExpiry > trialNow && trialFeatures.isNotEmpty && _businessMatches(config, trialBusinesses)) {
            final p = LicensePayload(
              licenseId: '${localTrial['licenseId'] ?? ''}', customerName: config?.storeName ?? '', phone: '',
              businessTypes: trialBusinesses, deviceId: currentDevice, platform: _currentPlatform(), plan: 'TRIAL', durationDays: 15,
              issuedAt: (localTrial['issuedAt'] as num?)?.toInt() ?? trialExpiry - const Duration(days:15).inMilliseconds, expiresAt: trialExpiry,
              priceAtPurchase: 0, currency: config?.currency ?? 'تومان', features: trialFeatures,
            );
            await _recordClock(db, wallNow);
            return LicenseStatus(valid:true, message:'دوره آزمایشی ۱۵ روزه معتبر است.', payload:p, remainingDays:((trialExpiry-wallNow)/Duration.millisecondsPerDay).ceil());
          }
        }
        return const LicenseStatus(valid:false, message:'لایسنس فعال نشده است.');
      }

      final decoded =
          jsonDecode(payloadJson);

      if (decoded is! Map) {
        return const LicenseStatus(
          valid: false,
          message:
              'اطلاعات لایسنس ذخیره‌شده معتبر نیست.',
        );
      }

      final payload =
          LicensePayload.fromMap(
        Map<String, dynamic>.from(
          decoded,
        ),
      );

      if (await _isLocallyRevoked(payload.licenseId)) {
        await db.insert('app_settings', {'key': _expiredLatchKey, 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
        return LicenseStatus(valid: false, message: 'این لایسنس توسط License Manager لغو/تعلیق شده است.', payload: payload);
      }

      if ((OnlineConfig.instance.required || !OnlineConfig.instance.baseUrl.contains('YOUR-DOMAIN')) && OnlineApiService.onlineEnabled) {
        try {
          final remote = await OnlineApiService.instance.publicLicenseValidate(licenseId: payload.licenseId, deviceId: await getDeviceId());
          if (remote['valid'] != true) {
            return LicenseStatus(valid:false, message:'لایسنس توسط سرور فعال نیست: ${remote['status'] ?? 'EXPIRED'}', payload:payload);
          }
        } catch(e) {
          // Do not ignore a definitive rejection from the API; keep offline
          // fallback only for transport/server outages, not revoked devices.
          if (e is ApiException && const {401, 403, 404}.contains(e.statusCode)) {
            return LicenseStatus(
              valid: false,
              message: 'لایسنس یا دستگاه از طرف سرور غیرفعال/لغو شده است (${e.statusCode}).',
              payload: payload,
            );
          }
          if (OnlineConfig.instance.required) {
            return LicenseStatus(valid:false, message:'اتصال به سرور لایسنس برقرار نشد: $e', payload:payload);
          }
        }
      }

      final signatureVersion = await LicenseCrypto.verifyPayload(
        payload.canonicalJson(),
        payload.legacyCanonicalJsonV1(),
        signature,
      );

      if (signatureVersion == null) {
        return LicenseStatus(
          valid: false,
          message: payload.storeCode.isNotEmpty
              ? 'امضای لایسنس معتبر نیست (Store: ${payload.storeCode}).'
              : 'امضای لایسنس معتبر نیست.',
          payload: payload,
        );
      }

      final currentPlatform =
          _currentPlatform();

      if (payload.platform != 'ALL' &&
          payload.platform !=
              currentPlatform) {
        return LicenseStatus(
          valid: false,
          message:
              'این لایسنس برای پلتفرم '
              '${payload.platform} صادر شده است.',
          payload: payload,
        );
      }

      final currentDevice =
          await getDeviceId();

      final sharedBinding =
          payload.platform.trim().toUpperCase() == 'ALL' ||
          payload.deviceBinding.trim().toUpperCase() == 'STORE_SHARED' ||
          payload.deviceId.trim().toUpperCase() == 'SHARED';

      if (!sharedBinding &&
          payload.deviceId.trim().toUpperCase() !=
              currentDevice.trim().toUpperCase()) {
        return const LicenseStatus(
          valid: false,
          message:
              'این لایسنس برای دستگاه دیگری صادر شده است.',
        );
      }

      if (!sharedBinding && !(await _secureBindingMatches(payload))) {
        // Existing installations created before the secure binding upgrade are
        // enrolled once, but only when the signed license already matches this
        // physical device. This avoids forcing a legitimate customer to buy
        // the same license again after an application update.
        final acceptedId = (await _secureStorage.read(key: _acceptedLicenseIdKey) ?? '').trim();
        if (acceptedId.isEmpty || acceptedId == payload.licenseId) {
          await _enrollSecureBinding(payload);
        } else {
          return const LicenseStatus(
            valid: false,
            message: 'اثبات امنیتی فعال‌سازی این لایسنس در این دستگاه معتبر نیست.',
          );
        }
      }

      if (!_businessMatches(
        config,
        payload.businessTypes,
      )) {
        return const LicenseStatus(
          valid: false,
          message:
              'نوع کسب‌وکار این فروشگاه '
              'در لایسنس فعال نیست.',
        );
      }

      final now = wallNow;

      if (await _clockWasRolledBack(map, now)) {
        return const LicenseStatus(
          valid: false,
          message:
              'ساعت سیستم به عقب برگشته است. برای جلوگیری از دور زدن لایسنس، '
              'تنظیم خودکار تاریخ و ساعت را فعال کنید.',
        );
      }

      if (now >= payload.expiresAt) {
        await db.transaction((txn) async {
          await txn.insert(
            'app_settings',
            {'key': _clockKey, 'value': '$now'},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.insert(
            'app_settings',
            {'key': _expiredLatchKey, 'value': '1'},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });
        await _writeClockSentinel(now);
        return LicenseStatus(valid: false, message: 'اعتبار لایسنس به پایان رسیده و برنامه قفل شده است.', payload: payload);
      }

      // فقط پس از عبور تمام بررسی‌های امنیتی
      // زمان آخرین بررسی را ذخیره می‌کنیم.
      await _recordClock(db, now);

      final days =
          ((payload.expiresAt - now) /
                  Duration
                      .millisecondsPerDay)
              .ceil();

      return LicenseStatus(
        valid: true,
        message:
            'لایسنس معتبر است.',
        payload: payload,
        remainingDays: days,
      );
    } catch (e) {
      return LicenseStatus(
        valid: false,
        message:
            'خطا در بررسی لایسنس: $e',
      );
    }
  }

  /// فقط لایسنس فعال را غیرفعال می‌کند؛ هیچ جدول یا داده تجاری حذف نمی‌شود.
  /// پس از این عملیات، کاربر می‌تواند لایسنس دیگری را از تنظیمات وارد کند.
  Future<void> deactivateActiveLicense() async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'app_settings',
        where: 'key IN (?, ?)',
        whereArgs: const [_payloadKey, _signatureKey],
      );
      await txn.insert(
        'app_settings',
        {'key': _expiredLatchKey, 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    // binding امن فعلی را عمداً نگه می‌داریم؛ حذف لایسنس نباید اطلاعات نصب
    // یا دیتابیس را پاک کند و فعال‌سازی بعدی همچنان ممکن است.
  }

  Future<void> activate(
    String licenseText, {
    StoreConfig? config,
  }) async {
    final text =
        licenseText.trim();

    if (text.isEmpty) {
      throw StateError(
        'متن لایسنس خالی است.',
      );
    }

    final doc =
        LicenseDocument.fromJson(text);

    final signatureVersion = await LicenseCrypto.verifyPayload(
      doc.payload.canonicalJson(),
      doc.payload.legacyCanonicalJsonV1(),
      doc.signatureBase64,
    );

    if (signatureVersion == null) {
      throw StateError(
        'امضای لایسنس معتبر نیست. فایل با کلید/فرمت معتبر StoreMaster امضا نشده است.',
      );
    }

    final currentPlatform =
        _currentPlatform();

    if (doc.payload.platform != 'ALL' &&
        doc.payload.platform !=
            currentPlatform) {
      throw StateError(
        'این لایسنس برای پلتفرم '
        '${doc.payload.platform} صادر شده است.',
      );
    }

    final currentDevice =
        await getDeviceId();

    final sharedBinding =
        doc.payload.platform.trim().toUpperCase() == 'ALL' ||
        doc.payload.deviceBinding.trim().toUpperCase() == 'STORE_SHARED' ||
        doc.payload.deviceId.trim().toUpperCase() == 'SHARED';

    if (!sharedBinding &&
        doc.payload.deviceId.trim().toUpperCase() !=
            currentDevice.trim().toUpperCase()) {
      throw StateError(
        'این لایسنس برای دستگاه فعلی صادر نشده است.',
      );
    }

    if (!await _acceptedLicenseCanBeReplaced(doc.payload)) {
      throw StateError(
        'این لایسنس قدیمی‌تر از لایسنس پذیرفته‌شده فعلی است و برای جلوگیری از بازگردانی لایسنس قدیمی پذیرفته نمی‌شود.',
      );
    }

    if (!_businessMatches(
      config,
      doc.payload.businessTypes,
    )) {
      throw StateError(
        'نوع کسب‌وکار فروشگاه با لایسنس تطابق ندارد.',
      );
    }

    final now =
        await _trustedNowMillis();

    if (now >=
        doc.payload.expiresAt) {
      throw StateError(
        'این لایسنس منقضی شده است.',
      );
    }

    if ((OnlineConfig.instance.required || !OnlineConfig.instance.baseUrl.contains('YOUR-DOMAIN')) && OnlineApiService.onlineEnabled) {
      final remote = await OnlineApiService.instance.publicLicenseValidate(licenseId: doc.payload.licenseId, deviceId: currentDevice);
      if (remote['valid'] != true) throw StateError('این لایسنس در سرور فعال نیست.');
    }

    final db =
        await _db.database;

    await db.transaction(
      (txn) async {
        await txn.insert(
          'app_settings',
          {
            'key': _payloadKey,
            'value': jsonEncode(
              doc.payload.toMap(),
            ),
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace,
        );

        await txn.insert(
          'app_settings',
          {
            'key': _signatureKey,
            'value':
                doc.signatureBase64,
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace,
        );

        await txn.insert(
          'app_settings',
          {
            'key': _clockKey,
            'value': '$now',
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace,
        );
        // فعال‌سازی یک لایسنس جدید پس از انقضا مجاز است؛ قفل فقط تا زمان
        // فعال‌سازی مجدد معتبر باقی می‌ماند.
        await txn.insert(
          'app_settings',
          {
            'key': _expiredLatchKey,
            'value': '0',
          },
          conflictAlgorithm:
              ConflictAlgorithm.replace,
        );
      },
    );

    await _writeClockSentinel(now);
    await _enrollSecureBinding(doc.payload);

    // آخرین بررسی همان لایسنس تازه ذخیره‌شده
    // باید معتبر باشد.
    final status =
        await validate(
      config: config,
    );

    if (!status.valid) {
      throw StateError(
        status.message,
      );
    }
  }

  /// دریافت لایسنس Shared از Windows Hub روی شبکه محلی.
  /// فقط لایسنس‌های مشترک پذیرفته می‌شوند و امضا دوباره بررسی می‌شود.
  Future<void> applySynchronizedLicense({
    required String payloadJson,
    required String signatureBase64,
  }) async {
    if (payloadJson.trim().isEmpty || signatureBase64.trim().isEmpty) {
      throw const FormatException('اطلاعات لایسنس همگام‌سازی‌شده ناقص است.');
    }

    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw const FormatException('ساختار لایسنس همگام‌سازی‌شده معتبر نیست.');
    }

    final payload = LicensePayload.fromMap(
      Map<String, dynamic>.from(decoded),
    );

    final isShared =
        payload.platform.trim().toUpperCase() == 'ALL' ||
        payload.deviceBinding.trim().toUpperCase() == 'STORE_SHARED' ||
        payload.deviceId.trim().toUpperCase() == 'SHARED';

    if (!isShared) {
      throw StateError(
        'لایسنس دستگاهی قابل انتقال از طریق Shared Sync نیست.',
      );
    }

    final signatureVersion = await LicenseCrypto.verifyPayload(
      payload.canonicalJson(),
      payload.legacyCanonicalJsonV1(),
      signatureBase64.trim(),
    );
    if (signatureVersion == null) {
      throw StateError(
        'امضای لایسنس همگام‌سازی‌شده معتبر نیست.',
      );
    }

    final now = await _trustedNowMillis();
    if (now >= payload.expiresAt) {
      throw StateError('لایسنس همگام‌سازی‌شده منقضی شده است.');
    }

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'app_settings',
        {
          'key': _payloadKey,
          'value': jsonEncode(payload.toMap()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {
          'key': _signatureKey,
          'value': signatureBase64.trim(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {
          'key': _clockKey,
          'value': '$now',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {
          'key': _expiredLatchKey,
          'value': '0',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _writeClockSentinel(now);
    await _enrollSecureBinding(payload);
  }

  Future<String> exportDeviceCard({
    StoreConfig? config,
  }) async {
    final id =
        await getDeviceId();

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}${Platform.pathSeparator}'
      'storemaster_device.txt',
    );

    await file.writeAsString(
      'StoreMaster Pro\n'
      'نام فروشگاه: ${config?.storeName ?? ''}\n'
      'نوع شغل: ${config?.businessTitle ?? config?.storeType ?? ''}\n'
      'Platform: ${_currentPlatform()}\n'
      'Device ID: $id\n',
      encoding: utf8,
    );

    return file.path;
  }

  bool get supportedPlatform =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isAndroid);

  /// بررسی قابلیت مجاز در لایسنس فعلی.
  /// FULL یا * به معنی دسترسی کامل است.
  bool hasFeature(LicensePayload? payload, String feature) {
    if (payload == null) return false;
    final features = payload.features.map((e) => e.trim()).toSet();
    return features.contains('*') ||
        features.contains('FULL') ||
        features.contains(feature);
  }
}
