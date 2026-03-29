import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'api_client.dart';
import '../utils/app_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// WebSocket STOMP — suivi des positions des livreurs disponibles (topic /topic/livreurs/positions).
/// Le backend diffuse un snapshot toutes les 10 s (Redis GEO + base).
class LivreurPositionsWebSocketService {
  static final LivreurPositionsWebSocketService _instance =
      LivreurPositionsWebSocketService._internal();
  factory LivreurPositionsWebSocketService() => _instance;
  LivreurPositionsWebSocketService._internal();

  final _storage = const FlutterSecureStorage();
  StompClient? _stomp;
  bool _connected = false;

  /// Dernière liste parsée { id, prenom, nom, lat, lon, ... }
  void Function(List<Map<String, dynamic>> livreurs)? onPositions;

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_connected) return;
    final token = await _storage.read(key: 'livreur_token');
    if (token == null || token.isEmpty) {
      AppLogger.log('[LivreursWS] Pas de token');
      return;
    }

    final wsUrl = ApiClient.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _stomp = StompClient(
      config: StompConfig(
        url: '$wsUrl/ws',
        onConnect: (StompFrame frame) {
          _connected = true;
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            final client = _stomp;
            if (client == null) return;
            client.subscribe(
              destination: '/topic/livreurs/positions',
              callback: (StompFrame f) {
                if (f.body == null) return;
                try {
                  final map = jsonDecode(f.body!) as Map<String, dynamic>;
                  final list = map['livreurs'];
                  if (list is List) {
                    final out = list
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                    onPositions?.call(out);
                  }
                } catch (e) {
                  AppLogger.error('[LivreursWS] parse', e);
                }
              },
            );
            AppLogger.log('[LivreursWS] Abonné /topic/livreurs/positions');
          });
        },
        onWebSocketError: (dynamic e) {
          _connected = false;
          AppLogger.error('[LivreursWS] erreur', e);
        },
        onDisconnect: (_) => _connected = false,
        heartbeatIncoming: const Duration(seconds: 20),
        heartbeatOutgoing: const Duration(seconds: 20),
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _stomp!.activate();
  }

  void disconnect() {
    try {
      _stomp?.deactivate();
    } catch (_) {}
    _stomp = null;
    _connected = false;
  }
}
