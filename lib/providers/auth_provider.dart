import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/livreur.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';

/// Provider d'authentification du livreur.
/// Centralise l'état de connexion accessible dans toute l'app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient();

  LivreurModel? _livreur;
  bool _isLoading = false;
  String? _error;

  LivreurModel? get livreur => _livreur;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _livreur != null;
  bool get isValide => _livreur?.isValide ?? false;
  bool get abonnementActif => _livreur?.abonnementActif ?? false;

  /// Vérifie la session au démarrage de l'app.
  /// Si un token existe, recharge le profil complet depuis le backend.
  Future<bool> checkSession() async {
    final hasToken = await _authService.isLoggedIn();
    AppLogger.log('[Auth] checkSession: hasToken=$hasToken');
    if (hasToken) {
      // Recharger le profil complet pour avoir toutes les données
      await refreshProfile();
      AppLogger.log('[Auth] checkSession: livreur=${_livreur?.fullName ?? "NULL"}');
      return _livreur != null;
    }
    return false;
  }

  /// Recharge le profil complet du livreur depuis le backend.
  /// Appel GET /api/livreur/profil pour récupérer toutes les infos à jour.
  Future<void> refreshProfile() async {
    try {
      final r = await _api.get('/api/livreur/profil');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final data = r.data['data'] as Map<String, dynamic>;
        AppLogger.log('[Auth] refreshProfile OK: prenom=${data['prenom']}, nom=${data['nom']}, photoSelfie=${data['photoSelfie'] != null}');
        _livreur = LivreurModel.fromJson(data);
        notifyListeners();
      } else {
        AppLogger.error('[Auth] refreshProfile: réponse inattendue', r.data);
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      AppLogger.error('[Auth] refreshProfile DioException: $statusCode', e.message);
      // Seulement déconnecter si token invalide/expiré (401/403)
      if (statusCode == 401 || statusCode == 403) {
        AppLogger.log('[Auth] Token invalide/expiré, déconnexion');
        await _authService.deleteToken();
        _livreur = null;
        notifyListeners();
      }
      // Sinon (500, timeout, réseau...) on garde le livreur existant
    } catch (e) {
      AppLogger.error('[Auth] refreshProfile erreur générale', e);
      // Ne PAS supprimer le token pour les erreurs non-auth
    }
  }

  /// Connexion livreur.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _livreur = await _authService.login(email, password);
      AppLogger.log('[Auth] login OK: ${_livreur?.fullName}, email=${_livreur?.email}');
      AppLogger.log('[Auth] login data: photoSelfie=${_livreur?.photoSelfie != null}, numeroCin=${_livreur?.numeroCin}');
      // Recharger le profil complet (essai admin, peutEtreDisponible) — même source que le dashboard
      await refreshProfile();
      await NotificationService().syncFcmTokenToBackendIfLoggedIn();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      AppLogger.error('[Auth] login ERREUR', _error);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion.
  Future<void> logout() async {
    await NotificationService().deleteTokenFromBackend();
    await _authService.logout();
    _livreur = null;
    notifyListeners();
  }

  /// Mettre à jour la disponibilité localement après toggle.
  void updateDisponibilite(bool disponible) {
    if (_livreur != null) {
      _livreur = _livreur!.copyWith(disponible: disponible);
      notifyListeners();
    }
  }

  /// Mettre à jour le profil livreur (après changement abonnement, etc.)
  void updateLivreur(LivreurModel updated) {
    _livreur = updated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
