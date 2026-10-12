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
    final client = HttpClient();

    try {
      final normalizedBase = baseUrl.replaceFirst(
        RegExp(r'/$'),
        '',
      );

      final normalizedPath = path.replaceFirst(
        RegExp(r'^/'),
        '',
      );

      final apiBase = '$normalizedBase/api/v1';
      final uri = Uri.parse(
        '$apiBase/$normalizedPath',
      );

      final request = await client.openUrl(
        method.toUpperCase(),
        uri,
      );

      request.headers.contentType = ContentType.json;

      // ----------------------------------------------------------------------
      // Authorization header
      // ----------------------------------------------------------------------
      if (token != null && token!.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${token!.trim()}',
        );
      }

      // ----------------------------------------------------------------------
      // Admin key
      // ----------------------------------------------------------------------
      if (adminKey.trim().isNotEmpty && adminKey != 'CHANGE_THIS_ADMIN_KEY') {
        request.headers.set(
          'X-Admin-Key',
          adminKey.trim(),
        );
      }

      // ----------------------------------------------------------------------
      // Body
      // ----------------------------------------------------------------------
      if (body != null) {
        request.write(
          jsonEncode(body),
        );
      }

      final response = await request.close();

      final responseText = await utf8.decoder.bind(response).join();

      Map<String, dynamic> data;

      if (responseText.trim().isEmpty) {
        data = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(responseText);

        if (decoded is Map) {
          data = Map<String, dynamic>.from(
            decoded,
          );
        } else {
          data = <String, dynamic>{
            'data': decoded,
          };
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          data['message']?.toString() ??
              data['error']?.toString() ??
              'خطای سرور',
          uri: uri,
        );
      }

      return data;
    } on SocketException catch (e) {
      throw Exception(
        'اتصال به سرور برقرار نشد: ${e.message}',
      );
    } on FormatException catch (e) {
      throw Exception(
        'پاسخ سرور JSON معتبر نیست: ${e.message}',
      );
    } finally {
      client.close(
        force: true,
      );
    }
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
