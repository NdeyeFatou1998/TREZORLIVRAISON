import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../models/livreur.dart';

/// Écran Modifier mes informations — affiche TOUTES les infos et images
/// soumises à l'inscription, avec possibilité de modifier les champs éditables.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient();

  late TextEditingController _prenomCtrl;
  late TextEditingController _nomCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _typeEnginCtrl;

  /// Données non éditables récupérées du profil
  LivreurModel? _livreur;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _livreur = context.read<AuthProvider>().livreur;
    _prenomCtrl = TextEditingController(text: _livreur?.prenom ?? '');
    _nomCtrl = TextEditingController(text: _livreur?.nom ?? '');
    _phoneCtrl = TextEditingController(text: _livreur?.phone ?? '');
    _typeEnginCtrl = TextEditingController(text: _livreur?.typeEngin ?? '');
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _phoneCtrl.dispose();
    _typeEnginCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await _api.put('/api/livreur/profile', data: {
        'prenom': _prenomCtrl.text.trim(),
        'nom': _nomCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'typeEngin': _typeEnginCtrl.text.trim(),
      });
      if (!mounted) return;
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null) {
          // Mettre à jour le provider avec les nouvelles données
          context.read<AuthProvider>().updateLivreur(LivreurModel.fromJson(Map<String, dynamic>.from(data)));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Mes informations'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section : Informations modifiables ──
              _buildSectionTitle('Informations personnelles', textColor),
              const SizedBox(height: 12),
              _buildTextField(_prenomCtrl, 'Prénom', Icons.person_outline, cardColor),
              const SizedBox(height: 12),
              _buildTextField(_nomCtrl, 'Nom', Icons.person_outline, cardColor),
              const SizedBox(height: 12),
              _buildTextField(_phoneCtrl, 'Téléphone', Icons.phone_outlined, cardColor, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField(_typeEnginCtrl, 'Type d\'engin', Icons.two_wheeler_outlined, cardColor, required: false, hint: 'Moto, Vélo, Voiture...'),
              const SizedBox(height: 12),
              // Email (lecture seule)
              _buildReadOnlyField('Email', _livreur?.email ?? '-', Icons.email_outlined, cardColor, secColor),
              const SizedBox(height: 12),
              // N° CIN (lecture seule)
              _buildReadOnlyField('N° Pièce d\'identité', _livreur?.numeroCin ?? '-', Icons.badge_outlined, cardColor, secColor),

              const SizedBox(height: 28),

              // ── Section : Documents soumis à l'inscription ──
              _buildSectionTitle('Documents d\'identité', textColor),
              const SizedBox(height: 4),
              Text('Soumis lors de l\'inscription. Contactez le support pour modifier.',
                  style: TextStyle(color: secColor, fontSize: 12)),
              const SizedBox(height: 14),

              // Photo selfie
              _buildImageCard('Photo selfie', _livreur?.photoSelfie, Icons.face, cardColor, textColor, secColor),
              const SizedBox(height: 12),

              // CIN Recto
              _buildImageCard('Pièce d\'identité (Recto)', _livreur?.photoCinRecto, Icons.credit_card, cardColor, textColor, secColor),
              const SizedBox(height: 12),

              // CIN Verso
              _buildImageCard('Pièce d\'identité (Verso)', _livreur?.photoCinVerso, Icons.credit_card, cardColor, textColor, secColor),
              const SizedBox(height: 12),

              // Photo engin
              _buildImageCard('Photo de l\'engin', _livreur?.photoEngin, Icons.two_wheeler, cardColor, textColor, secColor),

              const SizedBox(height: 32),

              // ── Bouton sauvegarder ──
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPurple, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer les modifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Titre de section
  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold));
  }

  /// Champ texte éditable
  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, Color fillColor,
      {TextInputType keyboard = TextInputType.text, bool required = true, String? hint}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: fillColor,
      ),
      validator: required ? (v) => v == null || v.trim().isEmpty ? '$label requis' : null : null,
    );
  }

  /// Champ lecture seule (email, N° CIN)
  Widget _buildReadOnlyField(String label, String value, IconData icon, Color fillColor, Color secColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.grey, size: 22),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: secColor, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ]),
        const Spacer(),
        const Icon(Icons.lock_outline, color: Colors.grey, size: 16),
      ]),
    );
  }

  /// Card avec image (selfie, CIN, engin) + placeholder si pas d'image
  Widget _buildImageCard(String label, String? imageUrl, IconData fallbackIcon, Color cardColor, Color textColor, Color secColor) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(fallbackIcon, size: 18, color: AppColors.deepPurple),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              if (hasImage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Soumis', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Non soumis', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
          // Image ou placeholder
          if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 180, color: Colors.grey.withValues(alpha: 0.1),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 180, color: Colors.grey.withValues(alpha: 0.1),
                  child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                ),
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(fallbackIcon, size: 32, color: secColor),
                  const SizedBox(height: 4),
                  Text('Aucune image', style: TextStyle(color: secColor, fontSize: 11)),
                ],
              )),
            ),
        ],
      ),
    );
  }
}
