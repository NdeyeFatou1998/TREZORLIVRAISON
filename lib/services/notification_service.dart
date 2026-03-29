import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as dev;

/// Service de gestion des notifications push Firebase.
/// Gère les notifications de livraisons (assignées, annulées, terminées).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialise Firebase Messaging et les notifications locales.
  Future<void> initialize() async {
    try {
      // Demander permission notifications
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        dev.log('[Notifications] Permission accordée');
        
        // Récupérer le token FCM
        _fcmToken = await _fcm.getToken();
        dev.log('[Notifications] FCM Token: $_fcmToken');

        // Initialiser notifications locales
        await _initLocalNotifications();

        // Écouter les messages en foreground
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Écouter les clics sur notifications
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

        // Vérifier si l'app a été ouverte via une notification
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationClick(initialMessage);
        }
      } else {
        dev.log('[Notifications] Permission refusée');
      }
    } catch (e) {
      dev.log('[Notifications] Erreur initialisation: $e');
    }
  }

  /// Initialise les notifications locales (Android/iOS).
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
        // TODO: Navigation vers l'écran approprié
      },
    );
  }

  /// Gère les messages reçus en foreground (app ouverte).
  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('[Notifications] Message foreground: ${message.notification?.title}');
    
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Trezor Livraison',
        body: notification.body ?? '',
        payload: data['type'] ?? '',
      );
    }

    // Traiter selon le type de notification
    _handleNotificationData(data);
  }

  /// Affiche une notification locale.
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'trezor_livraison',
      'Livraisons',
      channelDescription: 'Notifications de livraisons',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.aiff',
    );

    const details = NotificationDetails(
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

  /// Gère le clic sur une notification.
  void _handleNotificationClick(RemoteMessage message) {
    dev.log('[Notifications] Clic notification: ${message.data}');
    _handleNotificationData(message.data);
  }

  /// Traite les données de notification selon le type.
  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'NOUVELLE_LIVRAISON':
        dev.log('[Notifications] Nouvelle livraison disponible: ${data['livraisonId']}');
        // TODO: Rafraîchir la liste des livraisons disponibles
        break;
        
      case 'LIVRAISON_ASSIGNEE':
        dev.log('[Notifications] Livraison assignée: ${data['livraisonId']}');
        // TODO: Rafraîchir la liste des livraisons actives
        break;
        
      case 'LIVRAISON_ANNULEE':
        dev.log('[Notifications] Livraison annulée: ${data['livraisonId']}');
        // TODO: Rafraîchir et afficher message
        break;
        
      case 'LIVRAISON_TERMINEE':
        dev.log('[Notifications] Livraison terminée: ${data['livraisonId']}');
        // TODO: Rafraîchir historique
        break;
        
      default:
        dev.log('[Notifications] Type inconnu: $type');
    }
  }

  /// Envoie le token FCM au backend.
  Future<void> sendTokenToBackend(String token) async {
    // TODO: Implémenter l'envoi du token au backend
    dev.log('[Notifications] Envoi token au backend: $token');
  }

  /// Supprime le token FCM du backend (déconnexion).
  Future<void> deleteTokenFromBackend() async {
    // TODO: Implémenter la suppression du token
    dev.log('[Notifications] Suppression token du backend');
  }
}

/// Handler pour les messages en background (app fermée/arrière-plan).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  dev.log('[Notifications] Message background: ${message.notification?.title}');
}
