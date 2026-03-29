import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';

/// Écran Historique de paiements d'abonnement.
/// Affiche la liste des paiements avec statut, date, montant et lien facture PDF.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _paiements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaiements();
  }

  /// Charge l'historique des paiements d'abonnement depuis le backend
  Future<void> _loadPaiements() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final r = await _api.get('/api/livreur/abonnement/historique');
      if (r.statusCode == 200 && r.data['success'] == true) {
        final list = r.data['data'] as List<dynamic>? ?? [];
        _paiements = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ouvre la facture PDF dans le navigateur
  Future<void> _ouvrirFacture(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture non disponible'), backgroundColor: Colors.orange),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Historique de paiements'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: secColor)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadPaiements, child: const Text('Réessayer')),
                  ],
                ))
              : _paiements.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: secColor),
                        const SizedBox(height: 16),
                        Text('Aucun paiement', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Vos paiements d\'abonnement apparaîtront ici', style: TextStyle(color: secColor, fontSize: 13)),
                      ],
                    ))
                  : RefreshIndicator(
                      onRefresh: _loadPaiements,
                      color: AppColors.gold,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _paiements.length,
                        itemBuilder: (_, i) => _buildPaiementCard(_paiements[i], cardColor, textColor, secColor),
                      ),
                    ),
    );
  }

  /// Card individuelle pour chaque paiement
  Widget _buildPaiementCard(Map<String, dynamic> p, Color cardColor, Color textColor, Color secColor) {
    final statut = p['statut']?.toString() ?? '';
    final montant = p['montant']?.toString() ?? '2000';
    final refPaiement = p['refPaiement']?.toString() ?? '-';
    final modePaiement = p['modePaiement']?.toString() ?? '-';
    final urlFacture = p['urlFacture']?.toString();
    final numeroFacture = p['numeroFacture']?.toString();

    // Dates
    String dateStr = '-';
    try {
      final dateDebut = p['dateDebut'] ?? p['createdAt'];
      if (dateDebut != null) {
        dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateDebut.toString()));
      }
    } catch (_) {}

    String periodeStr = '';
    try {
      final dd = p['dateDebut'];
      final df = p['dateFin'];
      if (dd != null && df != null) {
        periodeStr = '${DateFormat('dd/MM').format(DateTime.parse(dd.toString()))} → ${DateFormat('dd/MM/yyyy').format(DateTime.parse(df.toString()))}';
      }
    } catch (_) {}

    // Couleur statut
    Color statutColor = Colors.grey;
    String statutLabel = statut;
    if (statut == 'ACTIF' || statut == 'PAYE') {
      statutColor = Colors.green;
      statutLabel = 'Payé';
    } else if (statut == 'EN_ATTENTE') {
      statutColor = Colors.orange;
      statutLabel = 'En attente';
    } else if (statut == 'ANNULE' || statut == 'ECHOUE') {
      statutColor = Colors.red;
      statutLabel = 'Échoué';
    } else if (statut == 'EXPIRE') {
      statutColor = Colors.grey;
      statutLabel = 'Expiré';
    }

    return GestureDetector(
      onTap: urlFacture != null ? () => _ouvrirFacture(urlFacture) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statutColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne titre + statut
            Row(children: [
              Icon(Icons.receipt, color: AppColors.deepPurple, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(
                numeroFacture ?? 'Abonnement mensuel',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statutColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statutLabel, style: TextStyle(color: statutColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),
            // Détails
            Row(children: [
              _buildDetail('Montant', '$montant FCFA', AppColors.gold, secColor),
              _buildDetail('Mode', modePaiement, textColor, secColor),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _buildDetail('Date', dateStr, textColor, secColor),
              if (periodeStr.isNotEmpty)
                _buildDetail('Période', periodeStr, textColor, secColor),
            ]),
            const SizedBox(height: 6),
            Text('Réf: $refPaiement', style: TextStyle(color: secColor, fontSize: 10)),
            // Lien facture PDF
            if (urlFacture != null && urlFacture.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Text('Voir la facture PDF', style: TextStyle(color: AppColors.deepPurple, fontSize: 13, fontWeight: FontWeight.w600)),
                const Icon(Icons.open_in_new, size: 14, color: AppColors.deepPurple),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  /// Petit widget détail (label + valeur) sur une demi-ligne
  Widget _buildDetail(String label, String value, Color valueColor, Color labelColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 10)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
