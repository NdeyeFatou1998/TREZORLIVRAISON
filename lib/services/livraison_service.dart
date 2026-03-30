import 'package:dio/dio.dart';
import '../models/livraison.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

/// Service pour toutes les opérations liées aux livraisons.
/// Cycle : disponibles → accepter → étapes → validation QR/OTP → preuve.
class LivraisonService {
  static final LivraisonService _instance = LivraisonService._internal();
  factory LivraisonService() => _instance;
  LivraisonService._internal();

  final ApiClient _api = ApiClient();

  // ── LISTES ──

  Future<List<LivraisonModel>> getLivraisonsDisponibles() async {
    try {
      final r = await _api.get('/api/livreur/livraisons/disponibles');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final list = r.data['data'] as List<dynamic>;
        return list.map((e) => LivraisonModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) { AppLogger.error('[Livraison] getLivraisonsDisponibles', e); }
    return [];
  }

  Future<List<LivraisonModel>> getLivraisonsActives() async {
    try {
      final r = await _api.get('/api/livreur/livraisons/actives');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final list = r.data['data'] as List<dynamic>;
        return list.map((e) => LivraisonModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) { AppLogger.error('[Livraison] getLivraisonsActives', e); }
    return [];
  }

  Future<List<LivraisonModel>> getHistorique() async {
    try {
      final r = await _api.get('/api/livreur/livraisons/historique');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final list = r.data['data'] as List<dynamic>;
        return list.map((e) => LivraisonModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) { AppLogger.error('[Livraison] getHistorique', e); }
    return [];
  }

  // ── SUIVI TEMPS RÉEL ──

  Future<LivraisonModel?> getSuivi(String livraisonId) async {
    try {
      final r = await _api.get('/api/livraisons/$livraisonId');
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
    } catch (e) { AppLogger.error('[Livraison] getSuivi', e); }
    return null;
  }

  // ── ACTIONS LIVREUR ──

  Future<LivraisonModel?> accepter(String livraisonId) async {
    try {
      final r = await _api.post('/api/livreur/livraisons/$livraisonId/accepter');
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data is Map ? e.response?.data['message'] : 'Erreur');
    }
    return null;
  }

  Future<LivraisonModel?> refuser(String livraisonId, {String? motif}) async {
    try {
      final r = await _api.post(
        '/api/livreur/livraisons/$livraisonId/refuser',
        data: {'motif': motif ?? 'Indisponible'},
      );
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data is Map ? e.response?.data['message'] : 'Erreur');
    }
    return null;
  }

  Future<LivraisonModel?> marquerEnRouteCollecte(String livraisonId) async {
    return _updateEtape('/api/livreur/livraisons/$livraisonId/en-route-collecte');
  }

  Future<LivraisonModel?> confirmerCollecte(String livraisonId) async {
    return _updateEtape('/api/livreur/livraisons/$livraisonId/confirmer-collecte');
  }

  Future<LivraisonModel?> marquerEnRouteLivraison(String livraisonId) async {
    return _updateEtape('/api/livreur/livraisons/$livraisonId/en-route-livraison');
  }

  Future<void> updatePosition(String livraisonId, double lat, double lon) async {
    try {
      await _api.put('/api/livreur/livraisons/$livraisonId/position',
          data: {'latitude': lat, 'longitude': lon});
    } catch (_) {}
  }

  // ── VALIDATION ──

  Future<LivraisonModel?> validerParQr(
      String livraisonId, String qrToken, String photoUrl, double lat, double lon) async {
    try {
      final r = await _api.post('/api/livreur/livraisons/$livraisonId/valider-qr', data: {
        'qrCodeToken': qrToken,
        'photoPreuveUrl': photoUrl,
        'latitude': lat,
        'longitude': lon,
      });
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data is Map ? e.response?.data['message'] : 'QR invalide');
    }
    return null;
  }

  Future<LivraisonModel?> validerParOtp(
      String livraisonId, String otp, String photoUrl, double lat, double lon) async {
    try {
      final r = await _api.post('/api/livreur/livraisons/$livraisonId/valider-otp', data: {
        'otp': otp,
        'photoPreuveUrl': photoUrl,
        'latitude': lat,
        'longitude': lon,
      });
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data is Map ? e.response?.data['message'] : 'OTP invalide');
    }
    return null;
  }

  // ── HELPERS ──

  Future<LivraisonModel?> _updateEtape(String path) async {
    try {
      final r = await _api.put(path);
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data is Map ? e.response?.data['message'] : 'Erreur');
    }
    return null;
  }
}
