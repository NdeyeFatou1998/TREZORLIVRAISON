import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Boîte de dialogue plein écran pour visualiser une facture (image PNG).
class FactureViewerDialog extends StatelessWidget {
  final Uint8List bytes;
  final String? numeroFacture;
  final String? titre;

  const FactureViewerDialog({
    super.key,
    required this.bytes,
    this.numeroFacture,
    this.titre,
  });

  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    String? numeroFacture,
    String? titre,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => FactureViewerDialog(
        bytes: bytes,
        numeroFacture: numeroFacture,
        titre: titre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0D0D1A),
      child: SafeArea(
        child: Column(
          children: [
            // ── Barre de titre ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1030),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2050), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: AppColors.gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre ?? 'Facture',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (numeroFacture != null && numeroFacture!.isNotEmpty)
                          Text(
                            numeroFacture!,
                            style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pinch, color: Colors.white38, size: 14),
                        SizedBox(width: 4),
                        Text('Pincer pour zoomer',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── Visionneuse ────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: const Color(0xFF0D0D1A),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Pied de page ───────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1030),
                border: Border(
                  top: BorderSide(color: Color(0xFF2A2050), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Colors.white24, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'Document officiel généré par TREZOR',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
