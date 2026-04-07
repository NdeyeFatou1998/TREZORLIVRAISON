import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as dev;

import 'api_client.dart';
import '../firebase_options.dart';

/// Service de gestion des notifications push Firebase.
/// Gère les notifications de livraisons et le rafraîchissement du profil (ex. période d'essai).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> Function()? _onRefreshProfil;
  Future<void> Function()? _onDeliveryEvent;

  /// Enregistré depuis [main] pour appeler [AuthProvider.refreshProfile] sans [BuildContext].
  void setOnRefreshProfil(Future<void> Function()? callback) {
    _onRefreshProfil = callback;
  }

  /// Callback optionnel pour rafraîchir les écrans livraison après push.
  void setOnDeliveryEvent(Future<void> Function()? callback) {
    _onDeliveryEvent = callback;
  }

  /// Initialise Firebase Messaging et les notifications locales.
  Future<void> initialize() async {
    try {
      // Android 13+ : POST_NOTIFICATIONS (indispensable pour afficher les push)
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final req = await Permission.notification.request();
          dev.log('[Notifications] Permission.notification Android: $req');
        }
      }

      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final ok = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (ok) {
        dev.log('[Notifications] Permission FCM: ${settings.authorizationStatus}');

        _fcmToken = await _fcm.getToken();
        if (_fcmToken == null || _fcmToken!.isEmpty) {
          dev.log(
            '[Notifications] Aucun token FCM — ajoutez android/app/google-services.json et ios/Runner/GoogleService-Info.plist '
            '(même projet Firebase que le backend) puis relancez l’app.',
          );
          return;
        }
        dev.log('[Notifications] FCM Token (préfixe): ${_fcmToken!.substring(0, _fcmToken!.length > 24 ? 24 : _fcmToken!.length)}…');

        _fcm.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          await sendTokenToBackend(newToken);
        });

        await _initLocalNotifications();

        FirebaseMessaging.onMessage.listen((m) async => _handleForegroundMessage(m));
        FirebaseMessaging.onMessageOpenedApp.listen((m) async => _handleNotificationClick(m));

        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          await _handleNotificationClick(initialMessage);
        }
      } else {
        dev.log('[Notifications] Permission notifications refusée — activez-les dans les réglages du téléphone pour recevoir les push.');
      }
    } catch (e) {
      dev.log('[Notifications] Erreur initialisation: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        dev.log('[Notifications] Clic local: ${details.payload}');
      },
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    dev.log('[Notifications] Message foreground: ${message.notification?.title}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Trezor Livraison',
        body: notification.body ?? '',
        payload: data['type'] ?? '',
      );
    }

    await _handleNotificationData(data);
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final isCadeauEssai = payload == 'PERIODE_ESSAI_ACCORDEE';

    final androidDetails = AndroidNotificationDetails(
      isCadeauEssai ? 'trezor_cadeau' : 'trezor_livraison',
      isCadeauEssai ? 'Cadeaux Trezor' : 'Livraisons',
      channelDescription: isCadeauEssai
          ? 'Bonus et essais offerts par Trezor'
          : 'Notifications de livraisons',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      color: isCadeauEssai ? const Color(0xFFC9A227) : null,
      styleInformation: isCadeauEssai
          ? BigTextStyleInformation(
              body,
              contentTitle: 'Trezor',
              summaryText: 'Cadeau offert',
            )
          : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: isCadeauEssai ? 'Offert par Trezor' : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _handleNotificationClick(RemoteMessage message) async {
    dev.log('[Notifications] Clic notification: ${message.data}');
    await _handleNotificationData(message.data);
  }

  Future<void> _handleNotificationData(Map<String, dynamic> data) async {
    final type = data['type']?.toString();

    switch (type) {
      case 'PERIODE_ESSAI_ACCORDEE':
      case 'REFRESH_LIVREUR_PROFIL':
        dev.log('[Notifications] Rafraîchissement profil (type=$type)');
        await _onRefreshProfil?.call();
        break;

      case 'NOUVELLE_LIVRAISON':
        dev.log('[Notifications] Nouvelle livraison disponible: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;

      case 'LIVRAISON_ASSIGNEE':
        dev.log('[Notifications] Livraison assignée: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;
      case 'LIVRAISON_PROPOSEE':
        dev.log('[Notifications] Livraison proposée: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;
      case 'DELIVERY_OFFERED':
        dev.log('[Notifications] Offre livraison: ${data['livraisonId']} (rayon=${data['searchRadiusKm']})');
        await _onDeliveryEvent?.call();
        break;
      case 'DELIVERY_TAKEN_BY_OTHER':
        dev.log('[Notifications] Offre prise par un autre livreur: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;
      case 'DELIVERY_ASSIGNED':
        dev.log('[Notifications] Livraison assignée: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;

      case 'LIVRAISON_ANNULEE':
        dev.log('[Notifications] Livraison annulée: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;

      case 'LIVRAISON_TERMINEE':
        dev.log('[Notifications] Livraison terminée: ${data['livraisonId']}');
        await _onDeliveryEvent?.call();
        break;

      default:
        dev.log('[Notifications] Type inconnu ou vide: $type');
    }
  }

  /// Enregistre le token FCM côté backend (JWT livreur requis).
  Future<void> sendTokenToBackend(String token) async {
    try {
      final api = ApiClient();
      final r = await api.put(
        '/api/livreur/fcm-token',
        data: {'fcmToken': token},
        options: Options(validateStatus: (s) => s != null && s < 600),
      );
      if (r.statusCode == 200 && r.data is Map && r.data['success'] == true) {
        dev.log('[Notifications] Token FCM enregistré côté serveur');
      } else {
        dev.log(
          '[Notifications] FCM token HTTP ${r.statusCode}: ${r.data}',
        );
      }
    } on DioException catch (e) {
      dev.log(
        '[Notifications] Envoi token échoué: ${e.response?.statusCode} — ${e.response?.data}',
      );
    } catch (e) {
      dev.log('[Notifications] Envoi token erreur: $e');
    }
  }

  /// Retire le token côté serveur (déconnexion).
  Future<void> deleteTokenFromBackend() async {
    try {
      final api = ApiClient();
      await api.put(
        '/api/livreur/fcm-token',
        data: {'fcmToken': ''},
        options: Options(validateStatus: (s) => s != null && s < 600),
      );
    } on DioException catch (e) {
      dev.log('[Notifications] Suppression token: ${e.response?.statusCode} — ${e.response?.data}');
    } catch (e) {
      dev.log('[Notifications] Suppression token erreur: $e');
    }
  }

  /// Après connexion ou au démarrage si une session existe.
  Future<void> syncFcmTokenToBackendIfLoggedIn() async {
    final jwt = await _storage.read(key: 'livreur_token');
    if (jwt == null || jwt.isEmpty) return;
    final token = _fcmToken ?? await _fcm.getToken();
    if (token == null || token.isEmpty) return;
    await sendTokenToBackend(token);
  }
}

/// Handler pour les messages en background (app fermée / arrière-plan).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log('[Notifications] Message background: ${message.notification?.title} data=${message.data}');
}
