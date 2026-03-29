import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../utils/app_logger.dart';

/// Service de géolocalisation GPS.
/// Récupère la position actuelle et suit les déplacements en temps réel.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;

  // ── PERMISSIONS ──

  /// Demande les permissions de localisation nécessaires.
  /// Retourne true si les permissions sont accordées.
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.log('[Location] Service GPS désactivé');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.log('[Location] Permission refusée');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.log('[Location] Permission refusée définitivement');
      return false;
    }

    return true;
  }

  // ── POSITION ACTUELLE ──

  /// Récupère la position GPS actuelle du livreur.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      AppLogger.error('[Location] Erreur position actuelle', e);
      return null;
    }
  }

  // ── SUIVI EN TEMPS RÉEL ──

  /// Démarre le suivi GPS en temps réel.
  /// [onPosition] : callback appelé à chaque nouvelle position.
  /// [intervalMs] : intervalle entre chaque mise à jour (défaut 5 secondes).
  void startTracking({
    required void Function(Position position) onPosition,
    int intervalMs = 5000,
  }) {
    stopTracking(); // Arrêter un éventuel tracking précédent
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour toutes les 10 mètres
      ),
    ).listen(
      (position) {
        AppLogger.log('[Location] ${position.latitude}, ${position.longitude}');
        onPosition(position);
      },
      onError: (e) => AppLogger.error('[Location] Erreur stream', e),
    );
  }

  /// Arrête le suivi GPS.
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calcule la distance en mètres entre deux points GPS.
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
