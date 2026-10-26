import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OnlineAdminService {
  // حالت آنلاین فعلا خاموش است. آینده فقط true شود.
  static const bool onlineEnabled = bool.fromEnvironment('STORE_MASTER_ADMIN_ONLINE_ENABLED', defaultValue: false);
  static final OnlineAdminService instance = OnlineAdminService._();

  OnlineAdminService._();

  String baseUrl = const String.fromEnvironment(
    'STORE_MASTER_API_URL',
    defaultValue: 'http://localhost:8080',
  );
  String fallbackUrl = const String.fromEnvironment(
    'STORE_MASTER_API_FALLBACK_URL',
    defaultValue: '',
  );

  List<String> get _baseUrls => <String>[baseUrl, fallbackUrl]
      .map((value) => value.trim().replaceFirst(RegExp(r'/$'), ''))
      .where((value) => value.isNotEmpty && !value.contains('YOUR-DOMAIN'))
      .toSet()
      .toList();

  String? token;

  final String adminKey = const String.fromEnvironment(
    'STORE_MASTER_ADMIN_KEY',
    defaultValue: 'CHANGE_THIS_ADMIN_KEY',
  );

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final bases = _baseUrls;
    if (bases.isEmpty) throw Exception('نشانی API تنظیم نشده است.');
    final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    final safeMethod = method.toUpperCase() == 'GET' || method.toUpperCase() == 'HEAD';
    Object? lastError;

    for (var i = 0; i < bases.length; i++) {
      final uri = Uri.parse('${bases[i]}/api/v1/$normalizedPath');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.openUrl(method.toUpperCase(), uri).timeout(const Duration(seconds: 10));
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (token != null && token!.trim().isNotEmpty) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token!.trim()}');
        }
        if (adminKey.trim().isNotEmpty && adminKey != 'CHANGE_THIS_ADMIN_KEY') {
          request.headers.set('X-Admin-Key', adminKey.trim());
        }
        if (body != null) request.write(jsonEncode(body));

        final response = await request.close().timeout(const Duration(seconds: 12));
        final responseText = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
        final retryableGateway = safeMethod && i + 1 < bases.length &&
            const {502, 503, 504, 520, 521, 522, 523, 524, 530}.contains(response.statusCode);
        if (retryableGateway) {
          lastError = HttpException('سرور اصلی در دسترس نیست', uri: uri);
          continue;
        }

        Map<String, dynamic> data;
        if (responseText.trim().isEmpty) {
          data = <String, dynamic>{};
        } else {
          final decoded = jsonDecode(responseText);
          data = decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{'data': decoded};
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(data['message']?.toString() ?? data['error']?.toString() ?? 'خطای سرور', uri: uri);
        }
        return data;
      } catch (error) {
        lastError = error;
        final retryableNetworkFailure = error is SocketException || error is TimeoutException;
        if (safeMethod && i + 1 < bases.length && retryableNetworkFailure) continue;
        if (error is SocketException) throw Exception('اتصال به سرور برقرار نشد: ${error.message}');
        if (error is FormatException) throw Exception('پاسخ سرور JSON معتبر نیست: ${error.message}');
        rethrow;
      } finally {
        client.close(force: true);
      }
    }
    throw Exception('سرور اصلی و جایگزین برای خواندن در دسترس نیستند: $lastError');
  }

  Future<Map<String, dynamic>> registerLicenseByDevice({
    required String deviceId, required String licenseId,
    required String customerName, required String phone,
    required String plan, required int expiresAt,
    required double originalPrice, required double finalPrice,
    required List<String> features, required List<String> businessTypes,
    required String platform, required String password, String discountCode = '',
  }) => request('POST', 'admin/licenses/by-device', body: {
    'deviceId': deviceId, 'licenseId': licenseId, 'customerName': customerName,
    'storeName': customerName, 'phone': phone, 'storeType': businessTypes.isEmpty ? 'GENERAL' : businessTypes.first,
    'businessTitle': businessTypes.isEmpty ? 'فروشگاه' : businessTypes.first,
    'currency': 'تومان', 'plan': plan, 'expiresAt': expiresAt,
    'originalPrice': originalPrice, 'finalPrice': finalPrice,
    'features': features, 'businessTypes': businessTypes, 'maxUsers': 10, 'discountCode': discountCode,
    'platform': platform, 'deviceName': 'StoreMaster Client', 'username': 'admin', 'password': password,
  });

  Future<Map<String, dynamic>> setLicenseStatus(String licenseId, String status) =>
      request('PATCH', 'admin/licenses/${Uri.encodeComponent(licenseId)}/status', body: {'status': status});

  Future<Map<String, dynamic>> getTrialPolicy() => request('GET', 'admin/trial-policy');

  Future<Map<String, dynamic>> updateTrialPolicy({
    required List<String> features,
    required List<String> businessTypes,
  }) => request('PUT', 'admin/trial-policy', body: {
    'features': features,
    'businessTypes': businessTypes,
  });


  Future<Map<String, dynamic>> fetchPricing() async {
    final data = await request('GET', 'admin/pricing');
    return data;
  }

  Future<Map<String, dynamic>> savePricing(Map<int, double> prices) async {
    final data = await request('PUT', 'admin/pricing', body: {
      'currency': 'تومان',
      'prices': {for (final entry in prices.entries) '${entry.key}': entry.value},
    });
    return data;
  }

  Future<List<Map<String, dynamic>>> supportTickets() async {
    final data = await request('GET', 'admin/support/tickets');
    return List<Map<String, dynamic>>.from(data['items'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> supportTicketMessages(String ticketCode, {int afterId = 0}) async {
    final data = await request('GET', 'admin/support/tickets/${Uri.encodeComponent(ticketCode)}/messages?afterId=$afterId');
    return List<Map<String, dynamic>>.from(data['items'] ?? const []);
  }

  Future<Map<String, dynamic>> replyToSupportTicket(String ticketCode, String message) =>
      request('POST', 'admin/support/tickets/${Uri.encodeComponent(ticketCode)}/messages', body: {'message': message});

  Future<Map<String, dynamic>> updateSupportTicketStatus(String ticketCode, String status) =>
      request('PATCH', 'admin/support/tickets/${Uri.encodeComponent(ticketCode)}/status', body: {'status': status});

  Future<Map<String, dynamic>> createDiscount({
    required String code,
    required int percent,
    required double fixedAmount,
    required int maxUses,
    DateTime? expiresAt,
  }) {
    return request(
      'POST',
      'admin/discounts',
      body: {
        'code': code,
        'percent': percent,
        'fixedAmount': fixedAmount,
        'maxUses': maxUses,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> quoteDiscount({
    required String code,
    required double originalPrice,
  }) {
    return request(
      'POST',
      'admin/discounts/quote',
      body: {
        'code': code,
        'originalPrice': originalPrice,
      },
    );
  }
}
