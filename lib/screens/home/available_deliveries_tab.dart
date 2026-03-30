import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/livraison.dart';
import '../../services/livraison_service.dart';
import '../delivery/active_delivery_screen.dart';

/// Onglet Disponibles — liste des livraisons sans livreur assigné.
/// Le livreur peut accepter une livraison en appuyant dessus.
class AvailableDeliveriesTab extends StatefulWidget {
  const AvailableDeliveriesTab({super.key});

  @override
  State<AvailableDeliveriesTab> createState() => _AvailableDeliveriesTabState();
}

class _AvailableDeliveriesTabState extends State<AvailableDeliveriesTab> {
  final LivraisonService _service = LivraisonService();
  List<LivraisonModel> _livraisons = [];
  bool _isLoading = true;
  String? _accepting;
  String? _refusing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _livraisons = await _service.getLivraisonsDisponibles();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _accepter(LivraisonModel l) async {
    setState(() => _accepting = l.id);
    try {
      final updated = await _service.accepter(l.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livraison acceptée ✅'), backgroundColor: Colors.green),
      );
      if (updated != null) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(livraison: updated)));
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _accepting = null);
    }
  }

  Future<void> _refuser(LivraisonModel l) async {
    setState(() => _refusing = l.id);
    try {
      await _service.refuser(l.id, motif: 'Indisponible');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livraison refusée'), backgroundColor: Colors.orange),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _refusing = null);
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
        title: const Text('Livraisons disponibles'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.gold,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _livraisons.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.local_shipping_outlined, size: 64, color: secColor),
                      const SizedBox(height: 16),
                      Text('Aucune livraison disponible', style: TextStyle(
                          color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Revenez plus tard ou actualisez la liste',
                          style: TextStyle(color: secColor, fontSize: 13)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _livraisons.length,
                    itemBuilder: (_, i) => _buildCard(_livraisons[i], cardColor, textColor, secColor),
                  ),
      ),
    );
  }

  Widget _buildCard(LivraisonModel l, Color cardColor, Color textColor, Color secColor) {
    final isAccepting = _accepting == l.id;
    final isRefusing = _refusing == l.id;
    final isProposee = l.statut == 'PROPOSEE';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.deepPurple.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.shopping_bag_outlined, color: AppColors.deepPurple, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(l.articleTitre ?? 'Commande',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis)),
              if (l.montantLivraison != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${l.montantLivraison!.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Collecte
                _buildAddressRow(Icons.store_outlined, 'Collecte',
                    l.adresseCollecte ?? 'Adresse vendeur', Colors.orange, secColor),
                const SizedBox(height: 10),
                const Center(child: Icon(Icons.arrow_downward, color: Colors.grey, size: 16)),
                const SizedBox(height: 10),
                // Livraison
                _buildAddressRow(Icons.home_outlined, 'Livraison',
                    l.adresseLivraison ?? 'Adresse acheteur', Colors.green, secColor),
                const SizedBox(height: 16),

                // Type livraison
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(l.typeLivraison).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _typeColor(l.typeLivraison).withValues(alpha: 0.4)),
                    ),
                    child: Text(_typeLivraisonLabel(l.typeLivraison),
                        style: TextStyle(color: _typeColor(l.typeLivraison),
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(l.createdAt.split('T').first, style: TextStyle(color: secColor, fontSize: 12)),
                ]),
                const SizedBox(height: 14),

                // Bouton accepter
                if (!isProposee)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: isAccepting ? null : () => _accepter(l),
                      icon: isAccepting
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(isAccepting ? 'Acceptation...' : 'Accepter cette livraison',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: isRefusing ? null : () => _refuser(l),
                            icon: isRefusing
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.close, size: 16),
                            label: const Text('Refuser'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: isAccepting ? null : () => _accepter(l),
                            icon: isAccepting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check, size: 16),
                            label: const Text('Accepter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String label, String address,
      Color iconColor, Color secColor) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: iconColor, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(address, style: TextStyle(color: secColor, fontSize: 13), maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }

  String _typeLivraisonLabel(String type) {
    switch (type) {
      case 'DIRECTE': return '🤝 Directe';
      case 'INDIRECTE': return '👥 Via tiers';
      case 'RETRAIT_PLACE': return '🏠 Retrait';
      default: return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'DIRECTE': return Colors.blue;
      case 'INDIRECTE': return Colors.purple;
      default: return Colors.teal;
    }
  }
}
