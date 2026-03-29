import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

/// Inscription livreur — 3 étapes :
/// Étape 1 : Infos personnelles (nom, téléphone, email, mot de passe)
/// Étape 2 : Documents KYC (CIN recto/verso, selfie avec CIN)
/// Étape 3 : Engin de livraison (type + photo)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  int _step = 1;
  bool _isLoading = false;

  // Étape 1
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // Étape 2 — docs KYC
  File? _cinRecto;
  File? _cinVerso;
  File? _selfie;
  final _numeroCinCtrl = TextEditingController();

  // Étape 3 — engin
  String _typeEngin = 'MOTO';
  File? _photoEngin;

  @override
  void dispose() {
    _prenomCtrl.dispose(); _nomCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _numeroCinCtrl.dispose();
    super.dispose();
  }

  // ── SÉLECTION IMAGES ──

  Future<void> _pickImage(String target) async {
    final picked = await _imagePicker.pickImage(
        source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      switch (target) {
        case 'cinRecto': _cinRecto = file; break;
        case 'cinVerso': _cinVerso = file; break;
        case 'selfie': _selfie = file; break;
        case 'engin': _photoEngin = file; break;
      }
    });
  }

  // ── SOUMISSION ──

  Future<void> _submit() async {
    if (_cinRecto == null || _cinVerso == null || _selfie == null || _photoEngin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tous les documents sont obligatoires'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Upload des 4 photos en parallèle
      final uploads = await Future.wait([
        _authService.uploadDoc(_cinRecto!.path, 'cin_recto'),
        _authService.uploadDoc(_cinVerso!.path, 'cin_verso'),
        _authService.uploadDoc(_selfie!.path, 'selfie'),
        _authService.uploadDoc(_photoEngin!.path, 'engin'),
      ]);

      // Inscription
      await _authService.register({
        'prenom': _prenomCtrl.text.trim(),
        'nom': _nomCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'typeEngin': _typeEngin,
        'numeroCin': _numeroCinCtrl.text.trim(),
        'photoCinRecto': uploads[0],
        'photoCinVerso': uploads[1],
        'photoSelfie': uploads[2],
        'photoEngin': uploads[3],
      });

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Inscription réussie ✅'),
          content: const Text(
              'Votre dossier a été soumis. L\'équipe Trezor va vérifier vos documents.\n\n'
              'Vous serez notifié(e) par email dès que votre compte est activé.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Inscription — Étape $_step/3'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _step > 1 ? setState(() => _step--) : Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barre de progression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _step / 3,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _step == 1 ? _buildStep1() : _step == 2 ? _buildStep2() : _buildStep3(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ÉTAPE 1 : Infos personnelles ──

  Widget _buildStep1() {
    return Column(key: const ValueKey(1), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('Informations personnelles'),
      const SizedBox(height: 20),
      _field(_prenomCtrl, 'Prénom', Icons.person_outline),
      const SizedBox(height: 14),
      _field(_nomCtrl, 'Nom', Icons.person_outline),
      const SizedBox(height: 14),
      _field(_phoneCtrl, 'Téléphone (ex: 77 123 45 67)', Icons.phone_outlined,
          type: TextInputType.phone),
      const SizedBox(height: 14),
      _field(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
      const SizedBox(height: 14),
      TextFormField(
        controller: _passwordCtrl,
        style: const TextStyle(color: Colors.white),
        obscureText: _obscure,
        decoration: _inputDecor('Mot de passe', Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: 32),
      _nextBtn(() {
        if (_prenomCtrl.text.isEmpty || _nomCtrl.text.isEmpty ||
            _phoneCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tous les champs sont requis'), backgroundColor: Colors.red));
          return;
        }
        setState(() => _step = 2);
      }),
    ]);
  }

  // ── ÉTAPE 2 : Documents KYC ──

  Widget _buildStep2() {
    return Column(key: const ValueKey(2), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('Documents d\'identité'),
      const SizedBox(height: 8),
      const Text('Ces documents permettent de vérifier votre identité. '
          'Toutes les photos doivent être nettes et lisibles.',
          style: TextStyle(color: Colors.white60, fontSize: 13)),
      const SizedBox(height: 24),
      
      // Numéro CIN
      _field(_numeroCinCtrl, 'Numéro CIN', Icons.numbers_outlined),
      const SizedBox(height: 14),
      
      _docUpload('CIN recto', 'cinRecto', _cinRecto, Icons.credit_card),
      const SizedBox(height: 14),
      _docUpload('CIN verso', 'cinVerso', _cinVerso, Icons.credit_card_outlined),
      const SizedBox(height: 14),
      _docUpload('Selfie avec votre CIN', 'selfie', _selfie, Icons.face),
      const SizedBox(height: 32),
      _nextBtn(() {
        if (_numeroCinCtrl.text.isEmpty || _cinRecto == null || _cinVerso == null || _selfie == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Le numéro CIN et les 3 documents sont obligatoires'), backgroundColor: Colors.red));
          return;
        }
        setState(() => _step = 3);
      }),
    ]);
  }

  // ── ÉTAPE 3 : Engin ──

  Widget _buildStep3() {
    final engins = ['MOTO', 'VOITURE', 'TRICYCLE'];
    return Column(key: const ValueKey(3), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _sectionTitle('Votre engin de livraison'),
      const SizedBox(height: 20),

      // Sélection type engin
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: engins.map((e) {
          final selected = _typeEngin == e;
          return GestureDetector(
            onTap: () => setState(() => _typeEngin = e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppColors.gold : Colors.white24),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_enginIcon(e), size: 18,
                    color: selected ? AppColors.deepPurple : Colors.white70),
                const SizedBox(width: 6),
                Text(e, style: TextStyle(
                    color: selected ? AppColors.deepPurple : Colors.white70,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      _docUpload('Photo de votre engin', 'engin', _photoEngin, _enginIcon(_typeEngin)),
      const SizedBox(height: 32),

      // Bouton soumettre
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: AppColors.deepPurple)
              : const Text('Soumettre mon dossier',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  // ── WIDGETS HELPERS ──

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold));

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        keyboardType: type,
        decoration: _inputDecor(hint, icon),
      );

  Widget _docUpload(String label, String target, File? file, IconData icon) {
    return GestureDetector(
      onTap: () => _pickImage(target),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: file != null ? AppColors.gold : Colors.white24, width: 1.5),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(file, fit: BoxFit.cover, width: double.infinity))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: Colors.white38, size: 32),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const Text('Appuyer pour prendre une photo',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
      ),
    );
  }

  Widget _nextBtn(VoidCallback onTap) => SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Continuer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );

  InputDecoration _inputDecor(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  IconData _enginIcon(String type) {
    switch (type) {
      case 'VOITURE': return Icons.directions_car_outlined;
      case 'VELO': return Icons.directions_bike_outlined;
      case 'TRICYCLE': return Icons.electric_rickshaw_outlined;
      default: return Icons.two_wheeler;
    }
  }
}
