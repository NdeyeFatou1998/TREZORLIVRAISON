import 'package:dio/dio.dart';
import '../models/livraison.dart';
import '../utils/api_error.dart';
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
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    } catch (e) {
      AppLogger.error('[Livraison] getLivraisonsDisponibles', e);
      throw ApiError(message: ApiError.messageOf(e));
    }
  }

  Future<List<LivraisonModel>> getLivraisonsActives() async {
    try {
      final r = await _api.get('/api/livreur/livraisons/actives');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final raw = r.data['data'];
        if (raw is! List) return [];
        final out = <LivraisonModel>[];
        for (final e in raw) {
          if (e is! Map) continue;
          try {
            out.add(LivraisonModel.fromJson(Map<String, dynamic>.from(e)));
          } catch (err) {
            AppLogger.error('[Livraison] parse active item ignoré', err);
          }
        }
        return out;
      }
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    } catch (e) {
      AppLogger.error('[Livraison] getLivraisonsActives', e);
      throw ApiError(message: ApiError.messageOf(e));
    }
  }

  Future<List<LivraisonModel>> getHistorique() async {
    try {
      final r = await _api.get('/api/livreur/livraisons/historique');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final list = r.data['data'] as List<dynamic>;
        return list.map((e) => LivraisonModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on ApiError {
      rethrow;
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    } catch (e) {
      AppLogger.error('[Livraison] getHistorique', e);
      throw ApiError(message: ApiError.messageOf(e));
    }
  }

  // ── SUIVI TEMPS RÉEL ──

  Future<LivraisonModel?> getSuivi(String livraisonId) async {
    try {
      final r = await _api.get('/api/livraisons/$livraisonId');
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      AppLogger.error('[Livraison] getSuivi', e);
      throw ApiError.fromDio(e);
    }
  }

  // ── ACTIONS LIVREUR ──

  Future<LivraisonModel?> accepter(String livraisonId) async {
    try {
      final r = await _api.post('/api/livreur/livraisons/$livraisonId/accepter');
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<LivraisonModel?> assignerParCode(String codeLivraison) async {
    try {
      final r = await _api.post('/api/livreur/livraisons/assigner-par-code', data: {
        'codeLivraison': codeLivraison.trim().toUpperCase(),
      });
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
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
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
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

  Future<void> updatePosition(String livraisonId, double lat, double lon, {double? heading}) async {
    try {
      final body = <String, dynamic>{
        'latitude': lat,
        'longitude': lon,
      };
      if (heading != null && heading >= 0) {
        body['heading'] = heading;
      }
      await _api.put('/api/livreur/livraisons/$livraisonId/position', data: body);
    } catch (e) {
      AppLogger.error('[Livraison] updatePosition', e);
    }
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
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
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
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  // ── HELPERS ──

  Future<LivraisonModel?> _updateEtape(String path) async {
    try {
      final r = await _api.put(path);
      if (r.statusCode == 200 && r.data['success'] == true) {
        return LivraisonModel.fromJson(r.data['data'] as Map<String, dynamic>);
      }
      throw ApiError.fromResponseBody(r.data, statusCode: r.statusCode);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
