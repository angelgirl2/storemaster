// ============================================================
// StoreMaster User - Online API Service
//
// وضعیت آنلاین از طریق dart-define قابل تنظیم است
//
// در این حالت:
// - هیچ درخواست HTTP به سرور ارسال نمی‌شود.
// - اطلاعات Session محلی خوانده می‌شود.
// - کدهای آنلاین و endpointها حفظ شده‌اند.
// - در آینده با true کردن ONLINE_ENABLED می‌توان آنلاین را فعال کرد.
// ============================================================

// ignore_for_file: unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import '../database/database_helper.dart';
import '../shared_src/online_models.dart';

import 'online_config.dart';
import 'online_session_store.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(
    this.statusCode,
    this.message,
  );

  @override
  String toString() => message;
}

class OnlineApiService {
  OnlineApiService._();

  static final OnlineApiService instance = OnlineApiService._();

  // ============================================================
  // MASTER ONLINE SWITCH
  //
  // پیش‌فرض خاموش است تا حالت آفلاین بدون سرور نیز اجرا شود.
  //
  // برای فعال‌سازی آنلاین در آینده:
  //
  // static const bool onlineEnabled = true;
  //
  // ============================================================

  // Online API is enabled only in builds that explicitly pass the release dart-defines.
  // Local SQLite continues to work offline; online operations retry/sync after reconnection.
  static const bool onlineEnabled = bool.fromEnvironment(
    'STORE_MASTER_ONLINE_ENABLED',
    defaultValue: false,
  );
  // ============================================================================
  // حالت آفلاین: تمام متدهای عمومی به‌جای تماس با سرور، مسیر محلی
  // برمی‌گردانند تا مصرف‌کننده (ViewModel / Screen) بدون exception ادامه دهد.
  // هیچ خطی حذف نشده است؛ فقط شاخه‌ی local-fallback افزوده شده.
  // ============================================================================

  final OnlineConfig config = OnlineConfig.instance;

  String? _token;
  String? _refresh;

  int _storeId = 0;

  bool get isAuthenticated => onlineEnabled && _token?.isNotEmpty == true;

  int get storeId => _storeId;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    // ----------------------------------------------------------
    // حتی در حالت آفلاین، Session محلی را می‌خوانیم تا ساختار
    // آینده حفظ شود؛ اما هیچ اتصال شبکه‌ای برقرار نمی‌شود.
    // ----------------------------------------------------------

    try {
      await config.load();
    } catch (_) {
      // Offline startup must not fail because of online config.
    }

    try {
      final session = await OnlineSessionStore.instance.read();

      final accessToken = '${session['accessToken'] ?? ''}';

      _token = accessToken.isEmpty ? null : accessToken;

      _refresh = '${session['refreshToken'] ?? ''}';

      _storeId = (session['storeId'] as num?)?.toInt() ?? 0;
    } catch (_) {
      _token = null;
      _refresh = null;
      _storeId = 0;
    }

    // ----------------------------------------------------------
    // ONLINE DISABLED
    // This mode restores local preferences only; it never issues cloud requests.
    // ----------------------------------------------------------

    if (!onlineEnabled) {
      return;
    }

    // ==========================================================
    // FUTURE ONLINE INITIALIZATION
    // ==========================================================

    // await _refreshSessionIfNeeded();
    // await sync();
  }

  // ============================================================
  // NETWORK REQUEST
  // ============================================================

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    // ========================================================================
    // LOCAL-FIRST: در حالت آفلاین (onlineEnabled=false) به‌جای پرتاب خطای 503
    // یک پاسخ محلی برمی‌گردانیم تا هیچ فراخوان آنلاینی نتواند مسیر آفلاین را
    // مختل کند. شاخه‌ی throw زیر برای حالت آنلاین آینده بدون تغییر حفظ شده.
    // ========================================================================
    if (!onlineEnabled) {
      return <String, dynamic>{
        'valid': true,
        'status': 'ACTIVE',
        'source': 'LOCAL_FALLBACK',
        'message': 'ارتباط آنلاین در نسخه فعلی غیرفعال است؛ پاسخ محلی بازگشت داده شد.',
      };
    }
    // ------------------------------------------------------------------------
    // (کامنت‌شده) شاخه‌ی خطای آفلاین — با توجه به پاسخ LOCAL_FALLBACK بالا دیگر
    // اجرا نمی‌شود. برای حالت آنلاین آینده (onlineEnabled=true) شاخه‌ی اصلی پایین
    // اجرا خواهد شد.
    // ------------------------------------------------------------------------
    // if (!onlineEnabled) {
    //   throw const ApiException(
    //     503,
    //     'ارتباط آنلاین در نسخه فعلی غیرفعال است.',
    //   );
    // }

    final bases = config.apiBaseUrls;
    if (bases.isEmpty) {
      throw const SocketException('آدرس API تنظیم نشده است.');
    }
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    Object? lastError;

    for (var i = 0; i < bases.length; i++) {
      final apiBase = bases[i];
      final uri = Uri.parse('$apiBase/api/v1/$normalizedPath');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.openUrl(method, uri).timeout(const Duration(seconds: 10));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        headers?.forEach((name, value) {
          if (name.trim().isNotEmpty && value.trim().isNotEmpty) request.headers.set(name, value);
        });
        if (auth && _token != null) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
        if (body != null) request.write(jsonEncode(body));

        final response = await request.close().timeout(const Duration(seconds: 12));
        final responseText = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
        final safeMethod = method == 'GET' || method == 'HEAD';
        final gatewayFailure = safeMethod && i + 1 < bases.length &&
            const {502, 503, 504, 520, 521, 522, 523, 524, 530}.contains(response.statusCode);
        if (gatewayFailure) {
          // A proxy/suspended-host error may return HTML rather than JSON.
          // Fall through before decoding the body so the backup can still be tried.
          lastError = ApiException(response.statusCode, 'سرور اصلی در دسترس نیست');
          continue;
        }
        final decoded = responseText.trim().isEmpty ? <String, dynamic>{} : jsonDecode(responseText);
        if (decoded is! Map) throw const FormatException('پاسخ سرور باید یک شیء JSON باشد.');
        final data = Map<String, dynamic>.from(decoded);
        if (response.statusCode >= 200 && response.statusCode < 300) return data;
        throw ApiException(response.statusCode, '${data['message'] ?? 'خطای سرور'}');
      } catch (error) {
        lastError = error;
        final safeMethod = method == 'GET' || method == 'HEAD';
        final retryableNetworkFailure = error is SocketException ||
            error is HttpException || error is TimeoutException;
        if (safeMethod && i + 1 < bases.length && retryableNetworkFailure) continue;
        rethrow;
      } finally {
        client.close(force: true);
      }
    }
    if (lastError is Exception) throw lastError;
    throw const SocketException('سرور اصلی و سرور جایگزین در دسترس نیستند.');
  }


  Future<int> serverTimeMillis() async {
    final data = await _request('GET', '/public/time', auth: false);
    final value = (data['serverTime'] as num?)?.toInt();
    if (value == null || value <= 0) {
      throw const FormatException('زمان سرور معتبر دریافت نشد.');
    }
    return value;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<OnlineSession> login({
    required String storeCode,
    required int userId,
    required String pin,
    required String deviceId,
  }) async {
    // ========================================================================
    // LOCAL FALLBACK - بدون تماس با سرور (onlineEnabled=false).
    // اگر در آینده آنلاین فعال شود، شاخه‌ی زیر با فراخوانی واقعی جایگزین
    // می‌شود (همچنان همان متد _request پایین‌تر). هیچ کدی حذف نشده.
    // ========================================================================
    if (!onlineEnabled) {
      final fallbackSession = OnlineSession.fromMap(<String, dynamic>{
        'storeId': userId,
        'userId': userId,
        'storeCode': storeCode,
        'storeName': '',
        'storeType': '',
        'businessTitle': '',
        'currency': '',
        'name': '',
        'role': 'OWNER',
        'accessToken': '',
        'refreshToken': '',
        'permissions': const <String>[],
        'features': const <String>[],
        'businessTypes': const <String>[],
        'licenseStatus': 'ACTIVE',
        'licensePlan': 'TRIAL',
        'licenseId': '',
        'licenseExpiresAt': DateTime.now()
            .add(const Duration(days: 15))
            .millisecondsSinceEpoch,
      });
      await OnlineSessionStore.instance.save(<String, dynamic>{
        'accessToken': fallbackSession.accessToken,
        'refreshToken': fallbackSession.refreshToken,
        'storeCode': fallbackSession.storeCode,
        'storeId': fallbackSession.storeId,
        'userId': fallbackSession.userId,
        'name': fallbackSession.name,
        'role': fallbackSession.role,
        'permissions': fallbackSession.permissions,
        'features': fallbackSession.features,
        'businessTypes': fallbackSession.businessTypes,
        'licenseExpiresAt': fallbackSession.licenseExpiresAt,
        'licenseStatus': fallbackSession.licenseStatus,
        'licenseId': fallbackSession.licenseId,
        'licensePlan': fallbackSession.licensePlan,
        'storeName': fallbackSession.storeName,
        'storeType': fallbackSession.storeType,
        'businessTitle': fallbackSession.businessTitle,
        'currency': fallbackSession.currency,
        'deviceId': deviceId,
        'platform': Platform.operatingSystem.toUpperCase(),
      });
      return fallbackSession;
    }
    // ================= شاخه‌ی آنلاین اصلی (بدون تغییر) =================
    final platform = Platform.isAndroid
        ? 'ANDROID'
        : Platform.isWindows
            ? 'WINDOWS'
            : Platform.operatingSystem.toUpperCase();

    final deviceName = await _deviceName();

    final data = await _request(
      'POST',
      '/auth/login',
      auth: false,
      body: {
        'storeCode': storeCode,
        'userId': userId,
        'pin': pin,
        'deviceId': deviceId,
        'platform': platform,
        'deviceName': deviceName,
      },
    );

    _token = '${data['accessToken'] ?? ''}';

    _refresh = '${data['refreshToken'] ?? ''}';

    _storeId = (data['storeId'] as num?)?.toInt() ?? 0;

    await OnlineSessionStore.instance.save({
      ...data,
      'deviceId': deviceId,
      'platform': platform,
    });

    return OnlineSession.fromMap(
      data,
    );
  }

  // ============================================================
  // STORE BOOTSTRAP
  // ============================================================

  Future<Map<String, dynamic>> bootstrapStore(
    Map<String, dynamic> body,
  ) async {
    // ----------------------------------------------------------------
    // Offline-safe fallback: هنگامی که آنلاین غیرفعال است، به‌جای پرتاب
    // خطای 503، یک پاسخ محلی سنتزی برمی‌گردانیم تا راه‌اندازی آفلاین
    // فروشگاه بدون خطا تکمیل شود. کلیدها دقیقاً همان‌هایی هستند که
    // مصرف‌کننده (MainViewModel.saveInitialSetup) انتظار دارد.
    // ----------------------------------------------------------------
    if (!onlineEnabled) {
      final trialExpire = DateTime.now()
          .add(const Duration(days: 15))
          .millisecondsSinceEpoch;
      return <String, dynamic>{
        'storeId': 0,
        'userId': 0,
        'storeCode': '',
        'licenseStatus': 'ACTIVE',
        'licenseExpiresAt': trialExpire,
        'licenseId': '',
        'licensePlan': 'TRIAL',
        'trialFeatures': const <String>[],
        'businessTypes': <String>[
          body['storeType']?.toString() ?? '',
        ],
        'permissions': const <String>[],
      };
    }
    return _request(
      'POST',
      '/stores/bootstrap',
      auth: false,
      body: body,
    );
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  Future<Map<String, dynamic>> me() {
    return _request(
      'GET',
      '/auth/me',
    );
  }

  // ============================================================
  // LICENSE STATUS
  // ============================================================

  Future<Map<String, dynamic>> licenseStatus() async {
    // لایه‌ی دفاعی دوم: اگر آنلاین خاموش است، یک پاسخ محلی فعال
    // برمی‌گردانیم تا فراخوان‌های فعال‌سازی به خطای 503 برخورد نکنند.
    if (!onlineEnabled) {
      return <String, dynamic>{
        'status': 'ACTIVE',
        'valid': true,
        'source': 'LOCAL_FALLBACK',
      };
    }
    return _request(
      'GET',
      '/licenses/me',
    );
  }

  // ============================================================
  // PUBLIC LICENSE VALIDATION
  // ============================================================

  Future<Map<String, dynamic>> publicLicenseValidate({
    required String licenseId,
    required String deviceId,
  }) async {
    // لایه‌ی دفاعی دوم: در حالت آفلاین، اعتبارسنجی سرور غیرفعال است
    // و به‌جای پرتاب خطای 503، یک پاسخ معتبر محلی برمی‌گردانیم تا
    // فراخوان‌های فعال‌سازی محلی (که قبلاً خودشان امضا، دستگاه، پلتفرم
    // و تاریخ انقضا را بررسی کرده‌اند) با موفقیت تکمیل شوند.
    if (!onlineEnabled) {
      return <String, dynamic>{
        'valid': true,
        'status': 'ACTIVE',
        'licenseId': licenseId,
        'deviceId': deviceId,
        'source': 'LOCAL_FALLBACK',
      };
    }
    return _request(
      'POST',
      '/licenses/activate',
      auth: false,
      body: {
        'licenseId': licenseId,
        'deviceId': deviceId,
      },
    );
  }

  // ============================================================
  // CLOUD SNAPSHOT
  // ============================================================

  Future<List<Map<String, dynamic>>> cloudSnapshot() async {
    final data = await _request(
      'GET',
      '/cloud-sync/snapshot',
    );

    return List<Map<String, dynamic>>.from(
      (data['items'] as List?) ?? const [],
    );
  }

  // ============================================================
  // CLOUD PUSH
  // ============================================================

  Future<Map<String, dynamic>> cloudPush(
    List<Map<String, dynamic>> items,
  ) {
    return _request(
      'POST',
      '/cloud-sync/push',
      body: {
        'items': items,
      },
    );
  }

  // ============================================================
  // USERS
  // ============================================================

  Future<List<Map<String, dynamic>>> users() async {
    final data = await _request(
      'GET',
      '/users',
    );

    return List<Map<String, dynamic>>.from(
      data['items'] ?? const [],
    );
  }

  Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> user,
  ) {
    return _request(
      'POST',
      '/users',
      body: user,
    );
  }

  Future<Map<String, dynamic>> updateUser(
    int id,
    Map<String, dynamic> user,
  ) {
    return _request(
      'PUT',
      '/users/$id',
      body: user,
    );
  }

  Future<Map<String, dynamic>> deleteUser(
    int id,
  ) {
    return _request(
      'DELETE',
      '/users/$id',
    );
  }

  // ============================================================
  // SUPPORT TICKET
  // ============================================================

  Future<Map<String, dynamic>> createSupportTicket({
    required String type,
    required String storeCode,
    required String licenseId,
    required String username,
    required String deviceId,
    required String contact,
    required String message,
  }) {
    return _request(
      'POST',
      '/support/tickets',
      body: {
        'type': type,
        'storeCode': storeCode,
        'licenseId': licenseId,
        'username': username,
        'deviceId': deviceId,
        'contact': contact,
        'message': message,
      },
    );
  }

  // ============================================================
  // LIVE SUPPORT CHAT (ticket-code capability token; does not require SMS)
  // ============================================================

  Future<Map<String, dynamic>> createLiveSupportTicket({
    required String type,
    required String storeCode,
    required String licenseId,
    required String username,
    required String deviceId,
    required String contact,
    required String message,
  }) async {
    if (!onlineEnabled) {
      throw const ApiException(503, 'گفت‌وگوی زنده در این Build خاموش است. نسخه آنلاین را با STORE_MASTER_ONLINE_ENABLED=true بسازید.');
    }
    return _request('POST', '/support/tickets', auth: false, body: {
      'type': type, 'storeCode': storeCode, 'licenseId': licenseId,
      'username': username, 'deviceId': deviceId, 'contact': contact,
      'message': message,
    });
  }

  Future<Map<String, dynamic>> supportMessages({
    required String ticketCode,
    required String accessKey,
    int afterId = 0,
  }) async {
    if (!onlineEnabled) throw const ApiException(503, 'اتصال آنلاین فعال نیست.');
    return _request('GET', '/support/tickets/${Uri.encodeComponent(ticketCode)}/messages?afterId=$afterId', auth: false,
      headers: {'X-Ticket-Access': accessKey});
  }

  Future<Map<String, dynamic>> sendSupportMessage({
    required String ticketCode,
    required String accessKey,
    required String message,
  }) async {
    if (!onlineEnabled) throw const ApiException(503, 'اتصال آنلاین فعال نیست.');
    return _request('POST', '/support/tickets/${Uri.encodeComponent(ticketCode)}/messages', auth: false,
      headers: {'X-Ticket-Access': accessKey}, body: {'message': message});
  }

  Future<Map<String, dynamic>> createOnlineInvoiceShare({
    required String invoiceNumber,
    required String dateText,
    required String customerName,
    required String currency,
    String storePhone = '',
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double discount,
    required double finalAmount,
    required double paidAmount,
    required double debtAmount,
  }) async {
    if (!onlineEnabled) throw const ApiException(503, 'برای ساخت لینک فاکتور باید نسخه آنلاین را با STORE_MASTER_ONLINE_ENABLED=true بسازید.');
    return _request('POST', '/invoices/share', body: {
      'invoiceNumber': invoiceNumber, 'dateText': dateText,
      'customerName': customerName, 'currency': currency, 'storePhone': storePhone, 'items': items,
      'totalAmount': totalAmount, 'discount': discount,
      'finalAmount': finalAmount, 'paidAmount': paidAmount, 'debtAmount': debtAmount,
    });
  }


  /// Fetches public license pricing without requiring a logged-in session.
  /// Returns an empty map when offline so the local-first workflow is preserved.
  Future<Map<String, dynamic>> fetchPublicPricing() async {
    if (!onlineEnabled) return <String, dynamic>{};
    try {
      return await _request('GET', '/public/pricing', auth: false);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Notifications are persisted by the server. Errors are swallowed so the
  /// local-first sales workflow remains functional when no network is available.
  Future<List<Map<String, dynamic>>> fetchNotifications({int afterId = 0}) async {
    if (!onlineEnabled || !isAuthenticated) return <Map<String, dynamic>>[];
    try {
      final data = await _request('GET', '/notifications?afterId=$afterId&take=50');
      return List<Map<String, dynamic>>.from((data['items'] as List?) ?? const []);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<int> unreadNotificationCount() async {
    if (!onlineEnabled || !isAuthenticated) return 0;
    try {
      final data = await _request('GET', '/notifications/unread-count');
      return (data['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead(int id) async {
    if (!onlineEnabled || !isAuthenticated || id <= 0) return;
    try { await _request('POST', '/notifications/$id/read'); } catch (_) {}
  }

  Future<void> publishEvent({
    required String eventType,
    required String title,
    required String message,
    String? entityId,
    String? platform,
  }) async {
    final eventId = '${DateTime.now().microsecondsSinceEpoch}-${entityId ?? 'event'}';
    final payload = <String, dynamic>{
      'eventId': eventId,
      'eventType': eventType,
      'title': title,
      'message': message,
      'entityId': entityId,
      'platform': platform,
    };
    if (onlineEnabled && isAuthenticated) {
      try {
        await _request('POST', '/notifications/events', body: payload);
        return;
      } catch (_) {
        // Fall through to the local outbox. It will retry after connectivity/session returns.
      }
    }
    await _queueNotificationEvent(payload, eventId);
  }

  Future<void> _queueNotificationEvent(
    Map<String, dynamic> payload,
    String eventId,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('sync_outbox', {
        'entity': 'notification_events',
        'operation': 'UPSERT',
        'entityId': eventId,
        'payloadJson': jsonEncode(payload),
        'sourceVersion': now,
        'createdAt': now,
      });
    } catch (_) {
      // Queue failure is best-effort; local sales and printing must never fail because of notifications.
    }
  }

  // ============================================================
  // DEVICE NAME
  // ============================================================

  Future<String> _deviceName() async {
    try {
      final info = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final android = await info.androidInfo;

        return '${android.manufacturer} '
            '${android.model}';
      }

      if (Platform.isWindows) {
        final windows = await info.windowsInfo;

        return windows.computerName;
      }

      if (Platform.isLinux) {
        final linux = await info.linuxInfo;

        return linux.prettyName;
      }

      if (Platform.isMacOS) {
        final mac = await info.macOsInfo;

        return mac.computerName;
      }
    } catch (_) {
      // Fall back below.
    }

    return Platform.operatingSystem;
  }

  // ============================================================
  // CLEAR ONLINE SESSION
  // ============================================================

  void clear() {
    _token = null;
    _refresh = null;
    _storeId = 0;
  }
}
