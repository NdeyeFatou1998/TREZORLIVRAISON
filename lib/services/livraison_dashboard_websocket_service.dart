import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import '../utils/app_logger.dart';

/// WebSocket STOMP des offres livraison côté livreur.
/// Topic backend: /topic/livreur/{livreurId}/dashboard
class LivraisonDashboardWebSocketService {
  static final LivraisonDashboardWebSocketService _instance =
      LivraisonDashboardWebSocketService._internal();
  factory LivraisonDashboardWebSocketService() => _instance;
  LivraisonDashboardWebSocketService._internal();

  final _storage = const FlutterSecureStorage();
  StompClient? _stomp;
  bool _connected = false;
  String? _currentLivreurId;

  void Function(Map<String, dynamic> event)? onEvent;
  bool get isConnected => _connected;

  Future<void> connect(String livreurId) async {
    if (_connected && _currentLivreurId == livreurId) return;
    disconnect();
    _currentLivreurId = livreurId;

    final token = await _storage.read(key: 'livreur_token');
    if (token == null || token.isEmpty) return;

    final wsUrl = ApiClient.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');

    _stomp = StompClient(
      config: StompConfig(
        url: '$wsUrl/ws',
        onConnect: (StompFrame frame) {
          _connected = true;
          Future<void>.delayed(const Duration(milliseconds: 300), () {
            final client = _stomp;
            if (client == null) return;
            client.subscribe(
              destination: '/topic/livreur/$livreurId/dashboard',
              callback: (StompFrame f) {
                if (f.body == null || f.body!.isEmpty) return;
                try {
                  final map = Map<String, dynamic>.from(jsonDecode(f.body!) as Map);
                  onEvent?.call(map);
                } catch (e) {
                  AppLogger.error('[LivraisonDashboardWS] parse', e);
                }
              },
            );
            AppLogger.log('[LivraisonDashboardWS] Abonné /topic/livreur/$livreurId/dashboard');
          });
        },
        onWebSocketError: (dynamic e) {
          _connected = false;
          AppLogger.error('[LivraisonDashboardWS] erreur', e);
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
