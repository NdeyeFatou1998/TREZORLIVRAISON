import 'package:flutter/material.dart';
import '../models/livreur.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

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
    if (hasToken) {
      // Recharger le profil complet pour avoir toutes les données
      await refreshProfile();
      return _livreur != null;
    }
    return false;
  }

  /// Recharge le profil complet du livreur depuis le backend.
  /// Appel GET /api/livreur/profil pour récupérer toutes les infos.
  Future<void> refreshProfile() async {
    try {
      final r = await _api.get('/api/livreur/profil');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final data = r.data['data'] as Map<String, dynamic>;
        _livreur = LivreurModel.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      // Si le profil ne peut pas être chargé (token expiré, etc.), déconnecter
      await _authService.deleteToken();
      _livreur = null;
      notifyListeners();
    }
  }

  /// Connexion livreur.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _livreur = await _authService.login(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion.
  Future<void> logout() async {
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
