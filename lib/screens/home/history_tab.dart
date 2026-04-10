import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/livraison.dart';
import '../../services/livraison_service.dart';

/// Onglet Historique — toutes les livraisons terminées du livreur.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => HistoryTabState();
}

class HistoryTabState extends State<HistoryTab> {
  final LivraisonService _service = LivraisonService();
  List<LivraisonModel> _historique = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Exposé au parent (HomeScreen) pour forcer le refresh.
  Future<void> refreshHistory() => _load();

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _historique = await _service.getHistorique();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Statistiques
    final total = _historique.length;
    final livrees = _historique.where((l) => l.statut == 'LIVREE').length;
    final echouees = _historique.where((l) => l.statut == 'ECHOUEE').length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Historique'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.gold,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : CustomScrollView(
                slivers: [
                  // Stats
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        _buildStat(cardColor, textColor, '${total}', 'Total', Icons.list_alt, Colors.blue),
                        const SizedBox(width: 10),
                        _buildStat(cardColor, textColor, '${livrees}', 'Livrées', Icons.check_circle, Colors.green),
                        const SizedBox(width: 10),
                        _buildStat(cardColor, textColor, '${echouees}', 'Échouées', Icons.cancel, Colors.red),
                      ]),
                    ),
                  ),

                  if (_historique.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.history, size: 64, color: secColor),
                          const SizedBox(height: 16),
                          Text('Aucune livraison dans l\'historique',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildCard(_historique[i], cardColor, textColor, secColor),
                          childCount: _historique.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildStat(Color cardColor, Color textColor, String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildCard(LivraisonModel l, Color cardColor, Color textColor, Color secColor) {
    final isLivree = l.statut == 'LIVREE';
    final statusColor = isLivree ? Colors.green : l.statut == 'ECHOUEE' ? Colors.red : Colors.orange;

    String dateStr = '';
    try {
      final date = DateTime.parse(l.dateLivraison ?? l.createdAt);
      dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    } catch (_) { dateStr = l.createdAt.split('T').first; }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isLivree ? Icons.check_circle_outline : Icons.info_outline,
              color: statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.articleTitre ?? 'Commande',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(l.statutLabel, style: TextStyle(color: statusColor, fontSize: 12,
              fontWeight: FontWeight.w600)),
          Text(dateStr, style: TextStyle(color: secColor, fontSize: 11)),
        ])),
        if (l.montantLivraison != null && l.statut == 'LIVREE')
          Text('${l.montantLivraison!.toStringAsFixed(0)} F',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}
