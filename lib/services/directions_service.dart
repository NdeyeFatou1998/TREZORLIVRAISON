import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Résultat d'un appel [Directions API] (itinéraire routier + métadonnées).
class DirectionsRouteData {
  final List<LatLng> points;
  final String? nextInstruction;
  final String? distanceRemainingText;
  final String? durationRemainingText;
  final String? errorMessage;

  const DirectionsRouteData({
    required this.points,
    this.nextInstruction,
    this.distanceRemainingText,
    this.durationRemainingText,
    this.errorMessage,
  });

  bool get isOk => errorMessage == null && points.isNotEmpty;
}

/// Itinéraire Google Directions (conduite) — polyline + prochaine manœuvre.
class DirectionsService {
  DirectionsService._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static String? get _apiKey {
    final a = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
    if (a != null && a.isNotEmpty) return a;
    final b = dotenv.env['GOOGLE_GEOLOCATION_API_KEY']?.trim();
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  static String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<DirectionsRouteData> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      return const DirectionsRouteData(
        points: [],
        errorMessage: 'Clé API Google absente (GOOGLE_MAPS_API_KEY ou GOOGLE_GEOLOCATION_API_KEY dans .env)',
      );
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: <String, dynamic>{
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'language': 'fr',
          'key': key,
        },
      );

      final data = res.data;
      if (data == null) {
        return const DirectionsRouteData(points: [], errorMessage: 'Réponse vide');
      }

      final status = data['status'] as String?;
      if (status != 'OK') {
        final msg = data['error_message'] as String? ?? status ?? 'Erreur Directions';
        return DirectionsRouteData(points: [], errorMessage: msg);
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return const DirectionsRouteData(points: [], errorMessage: 'Aucun itinéraire');
      }

      final route = routes.first as Map<String, dynamic>;
      final overview = route['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return const DirectionsRouteData(points: [], errorMessage: 'Polyline vide');
      }

      final decoded = PolylinePoints.decodePolyline(encoded);
      final points =
          decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

      final legs = route['legs'] as List<dynamic>?;
      String? nextInstr;
      String? distText;
      String? durText;

      if (legs != null && legs.isNotEmpty) {
        final leg = legs.first as Map<String, dynamic>;
        final steps = leg['steps'] as List<dynamic>?;
        if (steps != null && steps.isNotEmpty) {
          final step = steps.first as Map<String, dynamic>;
          final html = step['html_instructions'] as String? ?? '';
          nextInstr = _stripHtml(html);
        }
        final dist = leg['distance'] as Map<String, dynamic>?;
        final dur = leg['duration'] as Map<String, dynamic>?;
        distText = dist?['text'] as String?;
        durText = dur?['text'] as String?;
      }

      return DirectionsRouteData(
        points: points,
        nextInstruction: nextInstr,
        distanceRemainingText: distText,
        durationRemainingText: durText,
      );
    } on DioException catch (e) {
      return DirectionsRouteData(
        points: [],
        errorMessage: e.message ?? 'Réseau indisponible',
      );
    } catch (e) {
      return DirectionsRouteData(
        points: [],
        errorMessage: e.toString(),
      );
    }
  }
}
