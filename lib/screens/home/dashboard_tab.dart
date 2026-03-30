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
  State<DashboardTab> createState() => DashboardTabState();
}

class DashboardTabState extends State<DashboardTab> {
  final LivraisonService _livraisonService = LivraisonService();
  final ApiClient _api = ApiClient();
  final TextEditingController _codeController = TextEditingController();

  List<LivraisonModel> _actives = [];
  bool _isLoading = true;
  bool _togglingDisponibilite = false;
  bool _assigningByCode = false;
  String? _respondingMissionId;
  /// Variable locale pour feedback visuel immédiat du Switch
  bool? _localDisponible;

  @override
  void initState() {
    super.initState();
    _loadActives();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadActives() async {
    setState(() => _isLoading = true);
    _actives = await _livraisonService.getLivraisonsActives();
    if (mounted) setState(() => _isLoading = false);
  }

  /// Appelé depuis [HomeScreen] quand l’onglet Dashboard redevient actif.
  void refreshActives() => _loadActives();

  Future<void> _refreshAll() async {
    await context.read<AuthProvider>().refreshProfile();
    await _loadActives();
  }

  Future<void> _assignerParCode() async {
    if (_assigningByCode) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _assigningByCode = true);
    try {
      final livraison = await _livraisonService.assignerParCode(code);
      if (!mounted) return;
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livraison assignée via code ✅'), backgroundColor: Colors.green),
      );
      if (livraison != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(livraison: livraison)),
        );
      }
      if (mounted) await _loadActives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _assigningByCode = false);
    }
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

  /// Vérifie si le livreur peut utiliser la disponibilité (abonnement OU essai admin)
  bool _peutEtreDisponible() {
    final livreur = context.read<AuthProvider>().livreur;
    if (livreur == null) return false;
    return livreur.effectivePeutEtreDisponible;
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
        onRefresh: _refreshAll,
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
                  // ── Alerte si ni abonnement ni essai actif ──
                  if (!_peutEtreDisponible()) ...[
                    _buildAlertePasAcces(livreur),
                    const SizedBox(height: 12),
                  ],

                  // ── Toggle disponibilité ──
                  _buildDisponibiliteCard(disponible, cardColor, textColor),
                  const SizedBox(height: 20),

                  // ── Saisie code livraison ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entrer un code de livraison', style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w700, fontSize: 14,
                        )),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: A1B2C3D',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _assigningByCode ? null : _assignerParCode,
                                child: _assigningByCode
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Valider'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

  /// Card toggle disponibilité — grisé si pas d'abonnement ni d'essai actif
  Widget _buildDisponibiliteCard(bool disponible, Color cardColor, Color textColor) {
    final canToggle = _peutEtreDisponible();

    return GestureDetector(
      onTap: (canToggle && !_togglingDisponibilite) ? _toggleDisponibilite : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !canToggle
              ? Colors.grey.shade200.withValues(alpha: 0.3)
              : disponible ? Colors.green.withValues(alpha: 0.1) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: !canToggle
                  ? Colors.grey.shade300
                  : disponible ? Colors.green : Colors.grey.shade400,
              width: disponible && canToggle ? 2 : 1),
        ),
        child: Row(
          children: [
            // Icône animée
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: !canToggle ? Colors.grey.shade400 : disponible ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                !canToggle ? Icons.lock_outline : disponible ? Icons.wifi : Icons.wifi_off,
                color: Colors.white, size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !canToggle ? 'Indisponible' : disponible ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      color: !canToggle ? Colors.grey : disponible ? Colors.green : textColor,
                      fontWeight: FontWeight.bold, fontSize: 16,
                    ),
                  ),
                  Text(
                    !canToggle
                        ? 'Abonnement ou essai requis'
                        : disponible
                            ? 'Vous recevez des propositions de livraison'
                            : 'Appuyez pour recevoir des livraisons',
                    style: TextStyle(color: !canToggle ? Colors.red.shade300 : Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Switch — grisé et désactivé si pas autorisé
            _togglingDisponibilite
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))
                : Switch(
                    value: canToggle ? disponible : false,
                    onChanged: canToggle ? (_) => _toggleDisponibilite() : null,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.green,
                    inactiveThumbColor: canToggle ? Colors.white : Colors.grey.shade300,
                    inactiveTrackColor: canToggle ? Colors.grey.shade400 : Colors.grey.shade300,
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

  /// Statut abonnement/essai affiché dans le header
  Widget _buildStatutAbonnement(dynamic livreur) {
    // 1. Abonnement actif → priorité
    if (livreur?.abonnementActif == true) {
      return const Text('Abonnement actif', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600));
    }
    // 2. Période d'essai admin active
    if (livreur?.periodeEssaiActive == true) {
      final jours = livreur!.joursEssaiRestants;
      return Text('Période d\'essai: $jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''}',
          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.w600));
    }
    // 3. A déjà eu un abonnement → expiré
    if (livreur?.dateAbonnementExpiration != null) {
      return const Text('Abonnement expiré', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600));
    }
    // 4. A eu des jours d'essai → expirés
    if (livreur != null && livreur.joursEssaiAccordes > 0) {
      return const Text('Période d\'essai terminée (0 jour)', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600));
    }
    // 5. Jamais eu d'abonnement ni d'essai
    return const Text('Aucun abonnement', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600));
  }

  /// Alerte contextuelle si ni abonnement ni essai actif
  Widget _buildAlertePasAcces(dynamic livreur) {
    // Déterminer le message contextuel
    String message;
    IconData icon;
    Color color;

    if (livreur?.dateAbonnementExpiration != null && livreur?.abonnementActif != true) {
      // A eu un abonnement → il a expiré
      message = 'Votre abonnement a expiré. Renouvelez dans Profil pour continuer à livrer.';
      icon = Icons.credit_card_off;
      color = Colors.orange;
    } else if (livreur != null && livreur.joursEssaiAccordes > 0 && livreur.periodeEssaiActive != true) {
      // A eu une période d'essai → elle a expiré
      message = 'Votre période d\'essai est terminée (0 jour restant). Souscrivez à un abonnement pour continuer.';
      icon = Icons.timer_off;
      color = Colors.red;
    } else {
      // Jamais eu d'abonnement ni d'essai
      message = 'Aucun abonnement actif. Souscrivez (2 000 FCFA/mois) dans Profil pour accéder aux livraisons.';
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _openMission(LivraisonModel l) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(livraison: l)),
    );
    if (mounted) await _loadActives();
  }

  Future<void> _accepterProposition(LivraisonModel l) async {
    if (_respondingMissionId != null) return;
    setState(() => _respondingMissionId = l.id);
    try {
      final updated = await _livraisonService.accepter(l.id);
      if (!mounted) return;
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mission acceptée ✅'), backgroundColor: Colors.green),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(livraison: updated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingMissionId = null);
        await _loadActives();
      }
    }
  }

  Future<void> _refuserProposition(LivraisonModel l) async {
    if (_respondingMissionId != null) return;
    setState(() => _respondingMissionId = l.id);
    try {
      await _livraisonService.refuser(l.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposition refusée'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingMissionId = null);
        await _loadActives();
      }
    }
  }

  Widget _buildLivraisonCard(LivraisonModel l, Color cardColor, Color textColor, Color secColor) {
    final isProposee = l.statut == 'PROPOSEE';
    final busy = _respondingMissionId == l.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: isProposee ? null : () => _openMission(l),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                      Text(
                        l.articleTitre ?? 'Commande',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(l.statutLabel, style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                      if (l.adresseLivraison != null)
                        Text(
                          '📍 ${l.adresseLivraison!}',
                          style: TextStyle(color: secColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!isProposee)
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
          if (isProposee) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _refuserProposition(l),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : () => _accepterProposition(l),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
