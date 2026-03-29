import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../auth/login_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/payment_history_screen.dart';

/// Onglet Profil — photo + nom, statut, abonnement, boutons actions.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiClient _api = ApiClient();
  bool _loadingAbonnement = false;

  /// Initie un paiement PayTech pour l'abonnement
  Future<void> _payerAbonnement() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renouveler l\'abonnement'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant: 2 000 FCFA / mois',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 8),
            Text('Wave, Orange Money, Free Money', style: TextStyle(fontSize: 13, color: Colors.grey)),
            SizedBox(height: 12),
            Text('Vous serez redirigé vers la page de paiement sécurisée PayTech.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Payer maintenant'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _loadingAbonnement = true);
    try {
      final r = await _api.post('/api/livreur/abonnement/initier-paiement');
      if (!mounted) return;
      if (r.statusCode == 200 && r.data['success'] == true) {
        final redirectUrl = r.data['data']['redirectUrl'] as String?;
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          final uri = Uri.parse(redirectUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('URL de paiement non reçue');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _loadingAbonnement = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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

    // Calcul statut abonnement
    String expirationStr = 'Non abonné';
    bool periodeEssai = false;

    if (livreur?.abonnementActif == true && livreur?.dateAbonnementExpiration != null) {
      try {
        final dt = DateTime.parse(livreur!.dateAbonnementExpiration!);
        expirationStr = 'Expire le ${DateFormat('dd/MM/yyyy').format(dt)}';
      } catch (_) {}
    } else if (livreur?.createdAt != null) {
      try {
        final dateCreation = DateTime.parse(livreur!.createdAt!);
        final finEssai = dateCreation.add(const Duration(days: 3));
        if (DateTime.now().isBefore(finEssai)) {
          periodeEssai = true;
          final jours = finEssai.difference(DateTime.now()).inDays;
          expirationStr = '$jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''}';
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header : photo + nom + email + statut ──
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20, right: 20, bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.deepPurple, AppColors.deepPurpleLight],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              // Photo de profil
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                backgroundImage: (livreur?.photoSelfie != null && livreur!.photoSelfie!.isNotEmpty)
                    ? NetworkImage(livreur.photoSelfie!) : null,
                child: (livreur?.photoSelfie == null || livreur!.photoSelfie!.isEmpty)
                    ? const Icon(Icons.person, size: 44, color: AppColors.gold) : null,
              ),
              const SizedBox(height: 12),
              // Nom complet
              Text(
                livreur?.fullName ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // Email
              Text(livreur?.email ?? '', style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 8),
              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _statutColor(livreur?.statut).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statutLabel(livreur?.statut),
                    style: TextStyle(color: _statutColor(livreur?.statut), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Abonnement ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: (livreur?.abonnementActif == true ? Colors.green : periodeEssai ? Colors.blue : Colors.orange)
                          .withValues(alpha: 0.4)),
                ),
                child: Column(children: [
                  Row(children: [
                    Icon(livreur?.abonnementActif == true
                        ? Icons.verified
                        : periodeEssai ? Icons.schedule : Icons.warning_amber_outlined,
                        color: livreur?.abonnementActif == true
                            ? Colors.green
                            : periodeEssai ? Colors.blue : Colors.orange,
                        size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(livreur?.abonnementActif == true
                          ? 'Abonnement actif'
                          : periodeEssai ? 'Période d\'essai' : 'Abonnement expiré',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(expirationStr, style: TextStyle(color: secColor, fontSize: 12)),
                    ])),
                    const Text('2 000 F/mois', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 14),
                  // Bouton renouveler
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _loadingAbonnement ? null : _payerAbonnement,
                      icon: _loadingAbonnement
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.payment, size: 18),
                      label: const Text('Renouveler l\'abonnement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Boutons actions ──
              _buildActionTile(Icons.edit_outlined, 'Modifier mes informations', secColor, textColor, cardColor, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              }),
              const SizedBox(height: 10),
              _buildActionTile(Icons.receipt_long_outlined, 'Historique de paiements', secColor, textColor, cardColor, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
              }),
              const SizedBox(height: 24),

              // Déconnexion
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                  label: const Text('Se déconnecter', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Trezor Livraison v1.0.0', style: TextStyle(color: secColor, fontSize: 11)),
            ]),
          ),
        ],
      ),
    );
  }

  /// Tuile d'action cliquable (Modifier, Historique paiements)
  Widget _buildActionTile(IconData icon, String label, Color secColor, Color textColor, Color cardColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.deepPurple, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  String _statutLabel(String? statut) {
    switch (statut) {
      case 'VALIDE': return 'Compte validé';
      case 'EN_ATTENTE_VALIDATION': return 'En attente de validation';
      case 'SUSPENDU': return 'Compte suspendu';
      case 'BANNI': return 'Compte banni';
      default: return statut ?? '-';
    }
  }

  Color _statutColor(String? statut) {
    switch (statut) {
      case 'VALIDE': return Colors.green;
      case 'EN_ATTENTE_VALIDATION': return Colors.orange;
      case 'SUSPENDU': return Colors.orange;
      case 'BANNI': return Colors.red;
      default: return Colors.grey;
    }
  }
}
