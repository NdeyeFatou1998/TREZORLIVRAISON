import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../conditions_utilisation_screen.dart';
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
  final _phoneLocalCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _obscure = true;
  bool _acceptedTerms = false;
  bool _otpRequested = false;
  bool _phoneVerified = false;
  bool _otpLoading = false;
  String? _otpToken;
  String? _verifiedPhone;
  String _completePhone = '';

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
    _phoneLocalCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _numeroCinCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final s = value.trim();
    if (s.isEmpty || s.length > 254) return false;
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$').hasMatch(s);
  }

  String get _phoneForApi => _completePhone.replaceAll(RegExp(r'\s'), '');

  bool get _hasValidNationalPhone {
    final local = _phoneLocalCtrl.text.replaceAll(RegExp(r'\s'), '');
    return local.length >= 7;
  }

  bool get _hasValidPhone {
    final s = _phoneForApi;
    if (!_hasValidNationalPhone || s.length < 10) return false;
    return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(s);
  }

  void _onPhoneChanged(String completeNumber) {
    if (_verifiedPhone != null && completeNumber != _verifiedPhone) {
      setState(() {
        _phoneVerified = false;
        _otpToken = null;
        _verifiedPhone = null;
        _otpRequested = false;
        _otpCtrl.clear();
        _completePhone = completeNumber;
      });
      return;
    }
    setState(() => _completePhone = completeNumber);
  }

  bool get _canContinueStep1 {
    if (_prenomCtrl.text.trim().isEmpty || _nomCtrl.text.trim().isEmpty) return false;
    if (!_isValidEmail(_emailCtrl.text)) return false;
    if (!_hasValidPhone) return false;
    if (!_phoneVerified || _otpToken == null) return false;
    if (_verifiedPhone != _phoneForApi) return false;
    if (_passwordCtrl.text.isEmpty) return false;
    if (!_acceptedTerms) return false;
    return true;
  }

  bool get _canContinueStep2 {
    return _numeroCinCtrl.text.trim().isNotEmpty &&
        _cinRecto != null &&
        _cinVerso != null &&
        _selfie != null;
  }

  bool get _canSubmitFinal {
    return _canContinueStep1 && _canContinueStep2 && _photoEngin != null;
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
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez accepter les conditions d\'utilisation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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
        'phone': _phoneForApi,
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'typeEngin': _typeEngin,
        'numeroCin': _numeroCinCtrl.text.trim(),
        'photoCinRecto': uploads[0],
        'photoCinVerso': uploads[1],
        'photoSelfie': uploads[2],
        'photoEngin': uploads[3],
        'otpToken': _otpToken,
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

  Future<void> _requestOtp() async {
    if (!_hasValidPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro invalide'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      _otpLoading = true;
      _phoneVerified = false;
      _otpToken = null;
      _verifiedPhone = null;
    });
    try {
      await _authService.requestRegisterOtp(_phoneForApi);
      if (!mounted) return;
      setState(() => _otpRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code envoyé sur WhatsApp'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _otpLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez le code WhatsApp'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _otpLoading = true);
    try {
      final token = await _authService.verifyRegisterOtp(_phoneForApi, _otpCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _otpToken = token;
        _phoneVerified = true;
        _verifiedPhone = _phoneForApi;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro vérifié'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneVerified = false;
        _otpToken = null;
        _verifiedPhone = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _otpLoading = false);
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
      const Text(
        'Téléphone — pays (indicatif) puis numéro local',
        style: TextStyle(color: Colors.white60, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: IntlPhoneField(
          controller: _phoneLocalCtrl,
          initialCountryCode: 'SN',
          languageCode: 'fr',
          disableLengthCheck: false,
          invalidNumberMessage: 'Numéro invalide',
          decoration: const InputDecoration(
            hintText: 'Numéro sans indicatif',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            counterText: '',
          ),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          dropdownTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          dropdownIcon: Icon(Icons.arrow_drop_down, color: AppColors.gold.withValues(alpha: 0.7)),
          flagsButtonPadding: const EdgeInsets.only(left: 8),
          onChanged: (phone) => _onPhoneChanged(phone.completeNumber),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Code à 6 chiffres par WhatsApp (5 min).',
        style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.3),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _otpLoading ? null : _requestOtp,
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Code WhatsApp'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_phoneVerified) const Icon(Icons.verified, color: AppColors.success),
        ],
      ),
      if (_otpRequested) ...[
        const SizedBox(height: 10),
        _field(_otpCtrl, 'Code WhatsApp', Icons.verified_outlined, type: TextInputType.number),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _otpLoading ? null : _verifyOtp,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Valider le code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
      _field(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
      const SizedBox(height: 14),
      TextFormField(
        controller: _passwordCtrl,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white),
        obscureText: _obscure,
        decoration: _inputDecor('Mot de passe', Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _acceptedTerms
                ? AppColors.gold.withValues(alpha: 0.45)
                : Colors.white24,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _acceptedTerms ? Icons.check_circle : Icons.gavel_outlined,
                  color: _acceptedTerms ? AppColors.gold : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _acceptedTerms
                        ? 'Conditions d\'utilisation acceptées.'
                        : 'Ouvrez la page des conditions (identique au menu Profil), lisez et validez « J\'accepte » pour continuer.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final accepted = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ConditionsUtilisationScreen(),
                          ),
                        );
                        if (accepted == true && mounted) {
                          setState(() => _acceptedTerms = true);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
                ),
                child: Text(
                  _acceptedTerms ? 'Relire les conditions' : 'Lire et accepter les conditions',
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _nextBtn(
        enabled: _canContinueStep1,
        onTap: () {
          if (!_canContinueStep1) return;
          setState(() => _step = 2);
        },
      ),
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
      _nextBtn(
        enabled: _canContinueStep2,
        onTap: () {
          if (!_canContinueStep2) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Le numéro CIN et les 3 documents sont obligatoires'), backgroundColor: Colors.red));
            return;
          }
          setState(() => _step = 3);
        },
      ),
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
          onPressed: (_canSubmitFinal && !_isLoading) ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepPurple,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: AppColors.deepPurple)
              : Text(
                  'Soumettre mon dossier',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _canSubmitFinal ? AppColors.deepPurple : Colors.white38,
                  ),
                ),
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
        onChanged: (_) => setState(() {}),
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

  Widget _nextBtn({required bool enabled, required VoidCallback onTap}) => SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepPurple,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text('Continuer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: enabled ? AppColors.deepPurple : Colors.white38,
              )),
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
