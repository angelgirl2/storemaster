import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'local_device_identity.dart';
import 'license/license_service.dart';

class DiscoveredStore {
  final String host;
  final int port;
  final String licenseId;
  final String networkId;
  final String storeName;
  final String storeCode;
  final int expiresAt;
  final int maxDevices;
  final String deviceId;

  const DiscoveredStore({
    required this.host,
    required this.port,
    required this.licenseId,
    required this.networkId,
    required this.storeName,
    this.storeCode = '',
    this.expiresAt = 0,
    this.maxDevices = 1,
    this.deviceId = '',
  });

  String get key => '$host:$port:$licenseId';
}

class LocalNetworkSyncService extends ChangeNotifier {
  LocalNetworkSyncService._();
  static final instance = LocalNetworkSyncService._();

  static const int udpPort = 38644;
  static const int wsPort = 38645;
  static const String _protocol = 'STOREMASTER-LAN-1';
  static const Duration _discoveryInterval = Duration(seconds: 2);
  static const Duration _changeInterval = Duration(milliseconds: 350);

  HttpServer? _server;
  RawDatagramSocket? _udp; // server-side UDP discovery listener on udpPort
  RawDatagramSocket? _clientUdp; // ephemeral port for broadcasts/replies
  StreamSubscription? _udpSub;
  StreamSubscription? _clientUdpSub;
  Timer? _discoverTimer;
  Timer? _changeTimer;
  WebSocket? _hubSocket;
  String? _hubHost;
  String? _deviceId;
  bool _started = false;
  bool _applying = false;
  String _status = 'idle';
  int _dataChangeVersion = 0;
  final Set<WebSocket> _clients = <WebSocket>{};
  final Map<String, int> _remoteCursors = <String, int>{};
  final Map<String, DiscoveredStore> _discovered = <String, DiscoveredStore>{};
  Completer<void>? _initialSyncCompleter;
  bool _sharedLicenseReceived = false;
  bool _manualHubConnection = false;
  int _hubLastOwnSeq = 0;

  String get status => _status;
  bool get isLocalOnline => connected;
  String get userFacingStatus {
    if (connected) return 'متصل به شبکه محلی';
    if (_status == 'discovering') return 'در حال جستجوی رایانه فروشگاه…';
    if (_status == 'hub:waiting') return 'آماده برای اتصال محلی';
    if (_status == 'stopped') return 'اتصال محلی خاموش است';
    return 'آفلاین';
  }
  bool get connected => _hubSocket != null || _clients.isNotEmpty;
  String? get hubHost => _hubHost;
  int get dataChangeVersion => _dataChangeVersion;
  List<DiscoveredStore> get discoveredStores => List<DiscoveredStore>.unmodifiable(_discovered.values);

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    final db = await DatabaseHelper.instance.database;
    _deviceId = await LocalDeviceIdentity.instance.ensureDeviceId(db);
    await LocalDeviceIdentity.instance.reserveIdRange(db);
    if (Platform.isWindows || Platform.isAndroid) {
      await _startPeerNode(db);
    }
  }

  Future<void> stop() async {
    _discoverTimer?.cancel();
    _changeTimer?.cancel();
    await _udpSub?.cancel();
    await _clientUdpSub?.cancel();
    _udp?.close();
    _clientUdp?.close();
    _udp = null;
    _clientUdp = null;
    _clientUdpSub = null;
    _manualHubConnection = false;
    await _hubSocket?.close();
    _hubSocket = null;
    for (final s in List<WebSocket>.from(_clients)) { try { await s.close(); } catch (_) {} }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _started = false;
    _sharedLicenseReceived = false;
    _initialSyncCompleter?.complete();
    _initialSyncCompleter = null;
    _setStatus('stopped');
  }

  Future<String?> _localLicenseId() async {
    final db = await DatabaseHelper.instance.database;
    for (final key in const ['license_payload', 'local_trial_payload']) {
      final rows = await db.query('app_settings', columns: const ['value'], where: 'key=?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) continue;
      try {
        final value = jsonDecode('${rows.first['value']}');
        if (value is Map && '${value['licenseId'] ?? ''}'.trim().isNotEmpty) return '${value['licenseId']}'.trim();
      } catch (_) {}
    }
    return null;
  }

  Future<String> _storeName() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('store_config', columns: const ['storeName'], where: 'id=?', whereArgs: const [1], limit: 1);
    return rows.isEmpty ? 'StoreMaster' : '${rows.first['storeName'] ?? 'StoreMaster'}';
  }

  String _networkId(String licenseId) => base64UrlEncode(utf8.encode(licenseId)).replaceAll('=', '');

  Future<void> _startPeerNode(Database db) async {
    try {
      // Every supported device can host an incoming WebSocket and discover a
      // shared-license peer. A deterministic lowest-device-ID hub prevents
      // two peers from simultaneously opening duplicate outbound links.
      final license = await _localLicenseId();
      if (license != null) {
        final ownRows = await db.query('local_sync_log',
            columns: const ['originSeq'],
            where: 'originDeviceId=?', whereArgs: [_deviceId],
            orderBy: 'originSeq DESC', limit: 1);
        _hubLastOwnSeq = ownRows.isEmpty
            ? 0
            : (ownRows.first['originSeq'] as num?)?.toInt() ?? 0;
      }

      _server = await HttpServer.bind(InternetAddress.anyIPv4, wsPort, shared: true);
      _server!.listen((request) async {
        if (request.uri.path != '/ws') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        final licenseId = request.uri.queryParameters['licenseId'] ?? '';
        final deviceId = request.uri.queryParameters['deviceId'] ?? '';
        final networkId = request.uri.queryParameters['networkId'] ?? '';
        final sharedCandidate = request.uri.queryParameters['sharedCandidate'] == '1';
        final localLicense = await _localLicenseId();
        final db = await DatabaseHelper.instance.database;
        final sharedState = await _readSharedLicenseState(db);
        final localNetworkId = localLicense == null ? '' : _networkId(localLicense);
        // Only devices holding a cryptographically validated shared license
        // may accept LAN sync peers. Knowing a license ID alone is not enough.
        final candidateMatches = sharedState != null && localLicense != null &&
            licenseId == localLicense && networkId == localNetworkId;
        final provisionalMatches = sharedCandidate && sharedState != null &&
            licenseId == localLicense && networkId == localNetworkId;
        if (localLicense == null || deviceId.isEmpty ||
            (!candidateMatches && !provisionalMatches)) {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        _setStatus('hub:connected');
        socket.listen((raw) => _handleHubMessage(socket, raw), onDone: () {
          _clients.remove(socket);
          _setStatus(_clients.isEmpty ? 'hub:waiting' : 'hub:connected');
        }, onError: (_) {
          _clients.remove(socket);
          _setStatus(_clients.isEmpty ? 'hub:waiting' : 'hub:connected');
        });
        await _sendFullSnapshot(socket);
      });

      // The server socket answers broadcasts; a separate ephemeral socket
      // receives discovery replies, which is compatible with Android's UDP rules.
      _udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, udpPort,
        reuseAddress: Platform.isWindows,
        reusePort: Platform.isWindows,
      );
      _udpSub = _udp!.listen((event) async {
        if (event != RawSocketEvent.read) return;
        final socket = _udp;
        if (socket == null) return;
        final dg = socket.receive();
        if (dg == null) return;
        try {
          final msg = jsonDecode(utf8.decode(dg.data));
          if (msg is Map && msg['protocol'] == _protocol && msg['kind'] == 'discover') {
            _announce(dg.address, dg.port, requestedLicenseId: '${msg['licenseId'] ?? ''}');
          }
        } catch (_) {}
      });

      _clientUdp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 0, reuseAddress: false, reusePort: false);
      _clientUdp!.broadcastEnabled = true;
      _clientUdpSub = _clientUdp!.listen((event) async {
        if (event != RawSocketEvent.read) return;
        final socket = _clientUdp;
        if (socket == null) return;
        final dg = socket.receive();
        if (dg == null) return;
        try {
          final msg = jsonDecode(utf8.decode(dg.data));
          if (msg is Map && msg['protocol'] == _protocol &&
              msg['kind'] == 'hub' && msg['shared'] == true) {
            final item = DiscoveredStore(
              host: dg.address.address,
              port: (msg['port'] as num?)?.toInt() ?? wsPort,
              licenseId: '${msg['licenseId'] ?? ''}',
              networkId: '${msg['networkId'] ?? ''}',
              storeName: '${msg['storeName'] ?? 'StoreMaster'}',
              storeCode: '${msg['storeCode'] ?? ''}',
              expiresAt: (msg['expiresAt'] as num?)?.toInt() ?? 0,
              maxDevices: (msg['maxDevices'] as num?)?.toInt() ?? 1,
              deviceId: '${msg['deviceId'] ?? ''}',
            );
            if (item.licenseId.isNotEmpty && item.networkId.isNotEmpty &&
                item.deviceId.isNotEmpty && item.deviceId != _deviceId) {
              final wasNew = !_discovered.containsKey(item.key);
              _discovered[item.key] = item;
              if (wasNew) notifyListeners();
              final localLicense = await _localLicenseId();
              if (localLicense == item.licenseId && _hubSocket == null) {
                unawaited(_reconcileHubConnection());
              }
            }
          }
        } catch (_) {}
      });

      _discoverTimer = Timer.periodic(_discoveryInterval, (_) {
        _discover();
        _reconcileHubConnection();
      });
      _changeTimer = Timer.periodic(_changeInterval, (_) {
        _broadcastOwnChanges();
        _sendAndroidChanges();
      });
      _setStatus('hub:waiting');
      await _discover();
    } catch (e) {
      _udp?.close();
      _clientUdp?.close();
      _udp = null;
      _clientUdp = null;
      await _udpSub?.cancel();
      await _clientUdpSub?.cancel();
      _udpSub = null;
      _clientUdpSub = null;
      _discoverTimer?.cancel();
      _discoverTimer = null;
      _changeTimer?.cancel();
      _changeTimer = null;
      _setStatus('lan:error:$e');
    }
  }

  Future<void> _reconcileHubConnection() async {
    if (_manualHubConnection || _deviceId == null) return;
    final localLicense = await _localLicenseId();
    if (localLicense == null || localLicense.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    if (await _readSharedLicenseState(db) == null) return;
    final candidates = _discovered.values
        .where((x) => x.licenseId == localLicense &&
            x.deviceId.isNotEmpty && x.deviceId.compareTo(_deviceId!) < 0)
        .toList()
      ..sort((a, b) => a.deviceId.compareTo(b.deviceId));
    if (candidates.isEmpty) return; // this device is currently the elected hub
    final selected = candidates.first;
    if (_hubHost == selected.host && _hubSocket != null) return;
    final previous = _hubSocket;
    _hubSocket = null;
    _hubHost = null;
    try { await previous?.close(); } catch (_) {}
    await _connectToHub(selected.host, selected.port, selected.networkId,
        licenseIdOverride: selected.licenseId, provisional: false);
  }

  Future<void> _announce(InternetAddress target, int targetPort, {String requestedLicenseId = ''}) async {
    final license = await _localLicenseId();
    if (license == null || license.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final shared = await _readSharedLicenseState(db);
    if (shared == null) return;
    Map<String, dynamic> payload = const <String, dynamic>{};
    try {
      final raw = jsonDecode(shared['payloadJson']!);
      if (raw is Map) payload = Map<String, dynamic>.from(raw);
    } catch (_) {}
    final response = <String, dynamic>{
      'protocol': _protocol,
      'kind': 'hub',
      'port': wsPort,
      'deviceId': _deviceId ?? '',
      'networkId': _networkId(license),
      'licenseId': license,
      'storeName': await _storeName(),
      'storeCode': '${payload['storeCode'] ?? ''}',
      'expiresAt': (payload['expiresAt'] as num?)?.toInt() ?? 0,
      'maxDevices': (payload['maxDevices'] as num?)?.toInt() ?? 1,
      'shared': true,
    };
    if (requestedLicenseId.trim().isNotEmpty && requestedLicenseId.trim() != license) return;
    final bytes = utf8.encode(jsonEncode(response));
    try {
      _udp?.send(bytes, target, targetPort);
    } catch (_) {}
  }

  Future<void> _discover() async {
    final license = await _localLicenseId() ?? '';
    final bytes = utf8.encode(jsonEncode({
      'protocol': _protocol,
      'kind': 'discover',
      'deviceId': _deviceId,
      'licenseId': license,
    }));
    try {
      _clientUdp?.send(bytes, InternetAddress('255.255.255.255'), udpPort);
      if (_hubSocket == null) _setStatus('discovering');
    } catch (_) {}
  }

  Future<List<DiscoveredStore>> discoverStores({Duration wait = const Duration(seconds: 2)}) async {
    if (!_started) {
      await start();
    }
    await _discover();
    await Future<void>.delayed(wait);
    return discoveredStores;
  }

  Future<void> connectToDiscoveredStore(DiscoveredStore store, {bool waitForInitialSync = true}) async {
    if (!_started) await start();
    _manualHubConnection = true;
    final completer = Completer<void>();
    _initialSyncCompleter = completer;
    _sharedLicenseReceived = false;
    try {
      await _connectToHub(
        store.host,
        store.port,
        store.networkId,
        licenseIdOverride: store.licenseId,
        provisional: true,
      );
      if (_hubSocket == null) {
        throw StateError('اتصال به دستگاه فروشگاه برقرار نشد. Wi-Fi یکسان، مجوز شبکه محلی و پورت‌های 38644/38645 را بررسی کنید.');
      }
      if (waitForInitialSync) {
        await completer.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException('همگام‌سازی اولیه در ۲۰ ثانیه کامل نشد.'),
        );
      }
    } catch (_) {
      _manualHubConnection = false;
      rethrow;
    } finally {
      if (identical(_initialSyncCompleter, completer)) _initialSyncCompleter = null;
    }
  }

  Future<void> _connectToHub(String host, int port, String networkId, {String? licenseIdOverride, bool provisional = false}) async {
    final localLicense = await _localLicenseId();
    final license = (licenseIdOverride ?? localLicense ?? '').trim();
    if (license.isEmpty || networkId != _networkId(license) || _deviceId == null) {
      throw StateError('شناسه لایسنس یا دستگاه برای همگام‌سازی معتبر نیست.');
    }

    // A user may deliberately choose a different discovered store. Never
    // silently keep the old peer and then report a successful connection.
    final previous = _hubSocket;
    if (previous != null) {
      _hubSocket = null;
      _hubHost = null;
      try { await previous.close(); } catch (_) {}
    }

    try {
      final query = <String, String>{
        'licenseId': license,
        'deviceId': _deviceId!,
        'networkId': networkId,
        if (provisional) 'sharedCandidate': '1',
      };
      final uri = Uri(scheme: 'ws', host: host, port: port, path: '/ws', queryParameters: query);
      final socket = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 4));
      _hubSocket = socket;
      _hubHost = host;
      _setStatus('connected:$host');
      socket.listen(
        _handleAndroidMessage,
        onDone: () {
          if (identical(_hubSocket, socket)) {
            _hubSocket = null;
            _hubHost = null;
            _manualHubConnection = false;
            _setStatus('disconnected');
          }
        },
        onError: (_) {
          if (identical(_hubSocket, socket)) {
            _hubSocket = null;
            _hubHost = null;
            _manualHubConnection = false;
            _setStatus('disconnected');
          }
        },
      );
      socket.add(jsonEncode({'type':'hello','deviceId':_deviceId,'licenseId':license}));
      await _sendAndroidChanges();
    } catch (e) {
      _hubSocket = null;
      _hubHost = null;
      _setStatus('discovering');
      rethrow;
    }
  }

  bool _isLocalOnlySettingKey(String key) {
    final k = key.trim().toLowerCase();
    return k == 'local_sync_device_id' ||
        k.startsWith('license_') ||
        k.startsWith('local_trial_') ||
        k.startsWith('online_session') ||
        k == 'license_expired_latched';
  }

  Future<String?> _primaryKeyForTable(DatabaseExecutor db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info("$table")');
    if (info.isEmpty) return null;
    final explicitId = info.cast<Map<String, dynamic>>().any((c) => '${c['name']}' == 'id');
    if (explicitId) return 'id';
    for (final c in info) {
      if ((c['pk'] as num?)?.toInt() == 1) return '${c['name']}';
    }
    return '${info.first['name']}';
  }

  Future<List<Map<String, dynamic>>> _snapshotRows(Database db) async {
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    const excluded = {'sync_flags','sync_outbox','local_sync_log'};
    final result=<Map<String,dynamic>>[];
    for(final row in tables){
      final table='${row['name']}';
      if(excluded.contains(table)) continue;
      final pk = await _primaryKeyForTable(db, table);
      if (pk == null) continue;
      final rows=await db.query(table);
      for(final r in rows){
        if (table == 'app_settings' && _isLocalOnlySettingKey('${r['key'] ?? ''}')) continue;
        result.add({
          'originDeviceId':_deviceId,
          'originSeq':0,
          'entity':table,
          'operation':'UPSERT',
          'entityId':'${r[pk]}',
          'payloadJson':jsonEncode(r),
          'sourceVersion':DateTime.now().millisecondsSinceEpoch,
          'createdAt':DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    return result;
  }

  Future<void> _sendFullSnapshot(WebSocket socket) async {
    final db = await DatabaseHelper.instance.database;

    // Send the signed shared license first. Android can therefore activate the
    // same store license before replacing its local configuration with the
    // Windows store snapshot.
    final license = await _readSharedLicenseState(db);
    if (license != null) {
      socket.add(jsonEncode({
        'type': 'license_state',
        'payloadJson': license['payloadJson'],
        'signature': license['signature'],
      }));
    }

    final items = await _snapshotRows(db);
    const chunk = 150;
    final total = (items.length / chunk).ceil();
    if (items.isEmpty) {
      socket.add(jsonEncode({'type': 'snapshot', 'items': const [], 'chunk': 0, 'totalChunks': 0}));
    } else {
      for (var i = 0; i < items.length; i += chunk) {
        final index = (i ~/ chunk) + 1;
        socket.add(jsonEncode({
          'type': 'snapshot',
          'items': items.sublist(i, min(i + chunk, items.length)),
          'chunk': index,
          'totalChunks': total,
        }));
      }
    }
    socket.add(jsonEncode({'type': 'snapshot_end'}));
  }

  Future<Map<String, String>?> _readSharedLicenseState(Database db) async {
    try {
      final rows = await db.query(
        'app_settings',
        columns: const ['key', 'value'],
        where: 'key IN (?, ?)',
        whereArgs: const ['license_payload', 'license_signature'],
      );
      final map = <String, String>{
        for (final row in rows) '${row['key']}': '${row['value'] ?? ''}',
      };
      final payloadJson = map['license_payload'] ?? '';
      final signature = map['license_signature'] ?? '';
      if (payloadJson.isEmpty || signature.isEmpty) return null;

      final raw = jsonDecode(payloadJson);
      if (raw is! Map) return null;
      final payload = Map<String, dynamic>.from(raw);
      final shared =
          '${payload['platform'] ?? ''}'.toUpperCase() == 'ALL' ||
          '${payload['deviceBinding'] ?? ''}'.toUpperCase() == 'STORE_SHARED' ||
          '${payload['deviceId'] ?? ''}'.toUpperCase() == 'SHARED';
      if (!shared) return null;

      return {
        'payloadJson': jsonEncode(payload),
        'signature': signature,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _broadcastOwnChanges() async {
    if (_clients.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('local_sync_log', where:'originDeviceId=? AND originSeq>?', whereArgs:[_deviceId,_hubLastOwnSeq], orderBy:'originSeq ASC', limit:200);
    for(final r in rows){final op=Map<String,dynamic>.from(r); for(final s in List<WebSocket>.from(_clients)){try{s.add(jsonEncode({'type':'ops','deviceId':_deviceId,'items':[op]}));}catch(_){_clients.remove(s);}} _hubLastOwnSeq=(op['originSeq'] as num?)?.toInt() ?? _hubLastOwnSeq;}
  }

  Future<void> _sendAndroidChanges() async {
    final socket=_hubSocket; if(socket==null) return;
    final db=await DatabaseHelper.instance.database;
    final rows=await db.query('local_sync_log',where:'originDeviceId=? AND originSeq>?',whereArgs:[_deviceId,_remoteCursors['__sent'] ?? 0],orderBy:'originSeq ASC',limit:100);
    if(rows.isEmpty)return;
    final items=rows.map((r)=>Map<String,dynamic>.from(r)).toList();
    socket.add(jsonEncode({'type':'ops','deviceId':_deviceId,'items':items}));
    _remoteCursors['__sent']=(items.last['originSeq'] as num?)?.toInt() ?? (_remoteCursors['__sent'] ?? 0);
  }

  Future<void> _handleHubMessage(WebSocket socket,dynamic raw) async {
    try{
      final msg=jsonDecode('$raw'); if(msg is! Map)return;
      if(msg['type']=='ops'){
        final items=List<Map<String,dynamic>>.from((msg['items'] as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)));
        for(final op in items){
          await _applyOperation(op);
          await _storeRemoteLog(op);
        }
        if(items.isNotEmpty){socket.add(jsonEncode({'type':'ack','maxSeq':items.map((e)=>(e['originSeq'] as num?)?.toInt() ?? 0).fold<int>(0,max)})); await _broadcast(jsonEncode({'type':'ops','deviceId':'${msg['deviceId'] ?? ''}','items':items}));}
      }
    }catch(_){}
  }

  Future<void> _storeRemoteLog(Map<String,dynamic> op) async {
    final origin='${op['originDeviceId'] ?? ''}'; final seq=(op['originSeq'] as num?)?.toInt() ?? 0;
    if(origin.isEmpty || seq<=0)return;
    final db=await DatabaseHelper.instance.database;
    try{await db.insert('local_sync_log',{'originDeviceId':origin,'originSeq':seq,'entity':'${op['entity']}','operation':'${op['operation']}','entityId':'${op['entityId']}','payloadJson':'${op['payloadJson'] ?? jsonEncode(op['payload'] ?? {})}','sourceVersion':(op['sourceVersion'] as num?)?.toInt() ?? 0,'createdAt':(op['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch},conflictAlgorithm:ConflictAlgorithm.ignore);}catch(_){ }
  }

  Future<void> _handleAndroidMessage(dynamic raw) async {
    try{
      final msg=jsonDecode('$raw'); if(msg is! Map)return;
      if(msg['type']=='license_state'){
        try {
          await LicenseService.instance.applySynchronizedLicense(
            payloadJson: '${msg['payloadJson'] ?? ''}',
            signatureBase64: '${msg['signature'] ?? ''}',
          );
          _sharedLicenseReceived = true;
          _dataChangeVersion++;
          notifyListeners();
        } catch (_) {}
        return;
      }
      if(msg['type']=='snapshot_end'){
        final completer = _initialSyncCompleter;
        if (completer != null && !completer.isCompleted && (_sharedLicenseReceived || (await _localLicenseId())?.isNotEmpty == true)) {
          completer.complete();
        }
        return;
      }
      if(msg['type']=='snapshot' || msg['type']=='ops'){
        final items=List<Map<String,dynamic>>.from((msg['items'] as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)));
        for(final op in items){final origin='${op['originDeviceId'] ?? msg['deviceId'] ?? ''}'; if(origin==_deviceId)continue; await _applyOperation(op); final seq=(op['originSeq'] as num?)?.toInt() ?? 0; if(origin.isNotEmpty && seq>0)_remoteCursors[origin]=max(_remoteCursors[origin] ?? 0,seq);}
      }
    }catch(_){ }
  }

  Future<void> _applyOperation(Map<String,dynamic> op) async {
    final entity='${op['entity'] ?? ''}';
    if(entity.isEmpty || {'sync_flags','sync_outbox','local_sync_log'}.contains(entity))return;
    if (entity == 'app_settings' && _isLocalOnlySettingKey('${op['entityId'] ?? ''}')) return;
    final db=await DatabaseHelper.instance.database; if(_applying)return; _applying=true;
    var applied = false;
    try{
      await db.transaction((tx) async {
        await tx.insert('sync_flags',{'flag':'applying','value':'1'},conflictAlgorithm:ConflictAlgorithm.replace);
        try{
          final operation='${op['operation'] ?? 'UPSERT'}';
          final id='${op['entityId'] ?? ''}';
          final pk = await _primaryKeyForTable(tx, entity);
          if (pk == null) return;
          if(operation=='DELETE'){
            await tx.delete(entity,where:'CAST("$pk" AS TEXT)=?',whereArgs:[id]);
          }else{
            final payload=op['payload'] is Map?Map<String,dynamic>.from(op['payload']):Map<String,dynamic>.from(jsonDecode('${op['payloadJson'] ?? '{}'}'));
            if(payload.isNotEmpty)await tx.insert(entity,payload,conflictAlgorithm:ConflictAlgorithm.replace);
          }
          applied=true;
        }finally{await tx.delete('sync_flags',where:'flag=?',whereArgs:const ['applying']);}
      });
    }catch(_){ }finally{_applying=false;}
    if (applied) {
      // Data-version changes are the only reason MainViewModel should reload
      // its SQLite-backed collections. Connection/status changes remain UI-only.
      _dataChangeVersion++;
      notifyListeners();
    }
  }

  Future<void> _broadcast(String message) async {for(final s in List<WebSocket>.from(_clients)){try{s.add(message);}catch(_){_clients.remove(s);}}}
  void _setStatus(String value){if(_status==value)return;_status=value;notifyListeners();}
}
