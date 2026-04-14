import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/livreur.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

/// Service d'authentification livreur.
/// Appelle /api/livreur/auth/** (endpoints publics).
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _api = ApiClient();
  final _storage = const FlutterSecureStorage();

  // ── TOKEN MANAGEMENT ──

  Future<void> saveToken(String token) => _storage.write(key: 'livreur_token', value: token);
  Future<String?> getToken() => _storage.read(key: 'livreur_token');
  Future<void> deleteToken() => _storage.delete(key: 'livreur_token');

  /// Vérifie si un token est stocké (session active)
  Future<bool> isLoggedIn() async => (await getToken()) != null;

  // ── LOGIN ──

  /// Connexion livreur — retourne le LivreurModel + stocke le token
  Future<LivreurModel> login(String email, String password) async {
    try {
      final response = await _api.post('/api/livreur/auth/login',
          data: {'email': email, 'password': password});
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>;
        final token = data['accessToken'] as String;
        await saveToken(token);
        return LivreurModel.fromJson(data['livreur'] as Map<String, dynamic>);
      }
      throw Exception(response.data['message'] ?? 'Erreur connexion');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Erreur réseau')
          : (e.message ?? 'Erreur réseau');
      throw Exception(msg);
    }
  }

  // ── REGISTER ──

  /// Inscription livreur avec tous les docs KYC
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    try {
      final response = await _api.post('/api/livreur/auth/register', data: body);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Erreur inscription');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Erreur réseau')
          : (e.message ?? 'Erreur réseau');
      throw Exception(msg);
    }
  }

  // ── LOGOUT ──

  Future<void> logout() async {
    await deleteToken();
    AppLogger.log('[Auth] Livreur déconnecté');
  }

  // ── UPLOAD DOC ──

  /// Upload un fichier KYC (recto/verso CIN, selfie, engin)
  /// Retourne l'URL Cloudinary
  Future<String> uploadDoc(String filePath, String docType) async {
    try {
      final file = await MultipartFile.fromFile(filePath);
      // docType = 'cin_recto', 'cin_verso', 'selfie', 'engin' (pour info backend si besoin)
      // type = 'image' pour Cloudinary (obligatoire: 'image' ou 'video')
      final formData = FormData.fromMap({
        'file': file,
        'type': 'image',  // Cloudinary type: 'image' ou 'video'
        'docType': docType, // Type de document KYC (optionnel pour info)
      });
      final response = await _api.uploadFile('/api/files/upload', formData);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['url'] as String;
      }
      throw Exception('Erreur upload fichier');
    } catch (e) {
      AppLogger.error('[Auth] Erreur upload doc', e);
      rethrow;
    }
  }
}
