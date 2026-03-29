import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/livraison.dart';
import '../../services/livraison_service.dart';
import '../../services/api_client.dart';
import '../delivery/active_delivery_screen.dart';

/// Onglet Dashboard — aperçu des livraisons actives + toggle disponibilité.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final LivraisonService _livraisonService = LivraisonService();
  final ApiClient _api = ApiClient();

  List<LivraisonModel> _actives = [];
  bool _isLoading = true;
  bool _togglingDisponibilite = false;
  /// Variable locale pour feedback visuel immédiat du Switch
  bool? _localDisponible;

  @override
  void initState() {
    super.initState();
    _loadActives();
  }

  Future<void> _loadActives() async {
    setState(() => _isLoading = true);
    _actives = await _livraisonService.getLivraisonsActives();
    if (mounted) setState(() => _isLoading = false);
  }

  /// Toggle disponibilité avec feedback visuel immédiat
  Future<void> _toggleDisponibilite() async {
    if (_togglingDisponibilite) return;

    // Feedback visuel immédiat : inverser l'état local
    final ancienEtat = _localDisponible ?? context.read<AuthProvider>().livreur?.disponible ?? false;
    setState(() {
      _togglingDisponibilite = true;
      _localDisponible = !ancienEtat;
    });

    try {
      final r = await _api.put('/api/livreur/disponibilite');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final disponible = r.data['data']['disponible'] as bool;
        if (mounted) {
          context.read<AuthProvider>().updateDisponibilite(disponible);
          setState(() => _localDisponible = disponible);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(disponible ? '🟢 Vous êtes disponible' : '🔴 Vous êtes hors ligne'),
            backgroundColor: disponible ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 1),
          ));
        }
      }
    } catch (e) {
      // Rollback visuel en cas d'erreur
      if (mounted) {
        setState(() => _localDisponible = ancienEtat);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _togglingDisponibilite = false);
    }
  }

  /// Vérifie si abonnement actif ou en période d'essai (3 jours)
  bool _estAbonnementActifOuEssai() {
    final livreur = context.read<AuthProvider>().livreur;
    if (livreur == null) return false;
    if (livreur.abonnementActif) return true;
    if (livreur.createdAt == null) return false;
    try {
      final dateCreation = DateTime.parse(livreur.createdAt!);
      return DateTime.now().isBefore(dateCreation.add(const Duration(days: 3)));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final livreur = auth.livreur;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Utiliser la variable locale si disponible, sinon celle du provider
    final disponible = _localDisponible ?? livreur?.disponible ?? false;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: _loadActives,
        color: AppColors.gold,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header compact avec logo TREZOR ──
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20, right: 20, bottom: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.deepPurple, AppColors.deepPurpleLight],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo TREZOR
                  Row(children: [
                    const Text('TRE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const Text('ZOR', style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('LIVRAISON', style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  // Bonjour
                  Text('Bonjour, ${livreur?.prenom ?? ''} 👋',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  // Statut abonnement
                  _buildStatutAbonnement(livreur),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Alerte abonnement expiré ──
                  if (!_estAbonnementActifOuEssai()) ...[
                    _buildMessageAbonnementExpire(),
                    const SizedBox(height: 12),
                  ],

                  // ── Toggle disponibilité ──
                  _buildDisponibiliteCard(disponible, cardColor, textColor),
                  const SizedBox(height: 20),

                  // ── Livraisons actives ──
                  Text('Livraisons en cours', style: TextStyle(
                      color: textColor, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                    )
                  else if (_actives.isEmpty)
                    _buildEmpty(textColor, secColor)
                  else
                    ..._actives.map((l) => _buildLivraisonCard(l, cardColor, textColor, secColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card toggle disponibilité avec GestureDetector comme fallback
  Widget _buildDisponibiliteCard(bool disponible, Color cardColor, Color textColor) {
    return GestureDetector(
      onTap: _togglingDisponibilite ? null : _toggleDisponibilite,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: disponible ? Colors.green.withValues(alpha: 0.1) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: disponible ? Colors.green : Colors.grey.shade400,
              width: disponible ? 2 : 1),
        ),
        child: Row(
          children: [
            // Icône animée
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: disponible ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(disponible ? Icons.wifi : Icons.wifi_off, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(disponible ? 'En ligne' : 'Hors ligne',
                      style: TextStyle(color: disponible ? Colors.green : textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(disponible
                      ? 'Vous recevez des propositions de livraison'
                      : 'Appuyez pour recevoir des livraisons',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            // Switch Material avec thumbColor et trackColor Material States
            _togglingDisponibilite
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                : Switch(
                    value: disponible,
                    onChanged: (_) => _toggleDisponibilite(),
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.shade400,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color textColor, Color secColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.delivery_dining_outlined, size: 60, color: secColor),
          const SizedBox(height: 12),
          Text('Aucune livraison en cours', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          Text('Activez votre disponibilité pour recevoir des livraisons',
              style: TextStyle(color: secColor, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Statut abonnement affiché dans le header
  Widget _buildStatutAbonnement(dynamic livreur) {
    if (livreur?.abonnementActif == true) {
      return const Text('✅ Abonnement actif', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600));
    }
    if (livreur?.createdAt != null) {
      try {
        final dateCreation = DateTime.parse(livreur.createdAt);
        final finEssai = dateCreation.add(const Duration(days: 3));
        if (DateTime.now().isBefore(finEssai)) {
          final joursRestants = finEssai.difference(DateTime.now()).inDays;
          return Text('🎁 Période d\'essai: $joursRestants jour${joursRestants > 1 ? 's' : ''} restant${joursRestants > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.w600));
        }
      } catch (_) {}
    }
    return const Text('⚠️ Abonnement expiré', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600));
  }

  /// Alerte rouge si abonnement expiré
  Widget _buildMessageAbonnementExpire() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Votre abonnement a expiré. Allez dans Profil pour renouveler.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildLivraisonCard(LivraisonModel l, Color cardColor, Color textColor, Color secColor) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(livraison: l))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.articleTitre ?? 'Commande', style: TextStyle(
                      color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(l.statutLabel, style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                  if (l.adresseLivraison != null)
                    Text('📍 ${l.adresseLivraison!}',
                        style: TextStyle(color: secColor, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
