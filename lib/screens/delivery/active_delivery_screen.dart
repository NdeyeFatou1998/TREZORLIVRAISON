import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../models/livraison.dart';
import '../../services/livraison_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// ÉCRAN DE LIVRAISON ACTIVE — cœur de l'app Trezor Livraison
/// ═══════════════════════════════════════════════════════════════
/// Fonctionnalités :
/// - Carte Google Maps avec position livreur en temps réel
/// - Affichage vendeur (collecte) et acheteur (livraison) sur la carte
/// - Étapes de progression (en route collecte → collecté → en route livraison → livré)
/// - Scanner QR code (livraison directe)
/// - Saisie OTP (livraison indirecte)
/// - Photo preuve obligatoire avant validation finale
/// - Upload preuve + appel backend pour valider
class ActiveDeliveryScreen extends StatefulWidget {
  final LivraisonModel livraison;

  const ActiveDeliveryScreen({super.key, required this.livraison});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final LivraisonService _livraisonService = LivraisonService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  late LivraisonModel _livraison;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Timer? _refreshTimer;

  // Marqueurs carte
  final Set<Marker> _markers = {};

  // Photo preuve
  File? _photoPreuve;
  bool _isUploading = false;

  // UI
  bool _isLoading = false;
  bool _showValidationPanel = false;

  @override
  void initState() {
    super.initState();
    _livraison = widget.livraison;
    _initLocation();
    _startPositionTracking();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.stopTracking();
    _mapController?.dispose();
    super.dispose();
  }

  // ── LOCALISATION ──

  Future<void> _initLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentPosition = pos;
        _updateMarkers(pos.latitude, pos.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(
          LatLng(pos.latitude, pos.longitude)));
    }
  }

  void _startPositionTracking() {
    _locationService.startTracking(
      onPosition: (pos) async {
        if (!mounted) return;
        setState(() {
          _currentPosition = pos;
          _updateMarkers(pos.latitude, pos.longitude);
        });
        // Envoyer position au backend
        await _livraisonService.updatePosition(
            _livraison.id, pos.latitude, pos.longitude);
      },
      intervalMs: 5000,
    );
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final updated = await _livraisonService.getSuivi(_livraison.id);
      if (updated != null && mounted) {
        setState(() => _livraison = updated);
      }
    });
  }

  void _updateMarkers(double livreurLat, double livreurLon) {
    _markers.clear();
    // Position livreur (moi)
    _markers.add(Marker(
      markerId: const MarkerId('livreur'),
      position: LatLng(livreurLat, livreurLon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: const InfoWindow(title: 'Ma position'),
    ));
    // Vendeur (collecte)
    if (_livraison.latVendeur != null && _livraison.lonVendeur != null) {
      _markers.add(Marker(
        markerId: const MarkerId('vendeur'),
        position: LatLng(_livraison.latVendeur!, _livraison.lonVendeur!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: 'Collecte',
          snippet: _livraison.vendeur?['nom'] ?? 'Vendeur',
        ),
      ));
    }
    // Acheteur (livraison)
    if (_livraison.latAcheteur != null && _livraison.lonAcheteur != null) {
      _markers.add(Marker(
        markerId: const MarkerId('acheteur'),
        position: LatLng(_livraison.latAcheteur!, _livraison.lonAcheteur!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Livraison',
          snippet: _livraison.acheteur?['nom'] ?? 'Acheteur',
        ),
      ));
    }
  }

  // ── ACTIONS ÉTAPES ──

  Future<void> _executeAction(String action) async {
    setState(() => _isLoading = true);
    try {
      LivraisonModel? updated;
      switch (action) {
        case 'EN_ROUTE_COLLECTE':
          updated = await _livraisonService.marquerEnRouteCollecte(_livraison.id);
          break;
        case 'COLLECTE':
          updated = await _livraisonService.confirmerCollecte(_livraison.id);
          break;
        case 'EN_ROUTE_LIVRAISON':
          updated = await _livraisonService.marquerEnRouteLivraison(_livraison.id);
          break;
      }
      if (updated != null && mounted) {
        setState(() => _livraison = updated!);
        _showSnack(
          action == 'EN_ROUTE_COLLECTE' ? '🛵 En route vers le vendeur'
            : action == 'COLLECTE' ? '📦 Colis récupéré !'
            : '🛵 En route vers l\'acheteur',
          Colors.green,
        );
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── VALIDATION FINALE ──

  Future<void> _prendrePhoto() async {
    final picked = await _imagePicker.pickImage(
        source: ImageSource.camera, imageQuality: 75);
    if (picked != null) setState(() => _photoPreuve = File(picked.path));
  }

  Future<String?> _uploadPhoto() async {
    if (_photoPreuve == null) return null;
    setState(() => _isUploading = true);
    try {
      return await _authService.uploadDoc(_photoPreuve!.path, 'preuve_livraison');
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _validerParQr() async {
    if (_photoPreuve == null) {
      _showSnack('Prenez d\'abord une photo du colis livré', Colors.orange);
      return;
    }

    final qrToken = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (qrToken == null || !mounted) return;

    final photoUrl = await _uploadPhoto();
    if (photoUrl == null) {
      _showSnack('Erreur upload photo. Réessayez.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final pos = _currentPosition;
      final updated = await _livraisonService.validerParQr(
        _livraison.id, qrToken, photoUrl,
        pos?.latitude ?? 0.0, pos?.longitude ?? 0.0,
      );
      if (updated != null && mounted) {
        setState(() => _livraison = updated);
        _showSnack('✅ Livraison validée avec succès !', Colors.green);
        setState(() => _showValidationPanel = false);
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validerParOtp() async {
    if (_photoPreuve == null) {
      _showSnack('Prenez d\'abord une photo du colis livré', Colors.orange);
      return;
    }

    // Saisie OTP
    final otpCtrl = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Code OTP'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Demandez le code au receveur',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 5,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                letterSpacing: 12),
            decoration: const InputDecoration(
              hintText: '00000',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, otpCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (otp == null || otp.isEmpty || !mounted) return;

    final photoUrl = await _uploadPhoto();
    if (photoUrl == null) {
      _showSnack('Erreur upload photo. Réessayez.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final pos = _currentPosition;
      final updated = await _livraisonService.validerParOtp(
        _livraison.id, otp, photoUrl,
        pos?.latitude ?? 0.0, pos?.longitude ?? 0.0,
      );
      if (updated != null && mounted) {
        setState(() => _livraison = updated);
        _showSnack('✅ Livraison validée avec succès !', Colors.green);
        setState(() => _showValidationPanel = false);
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)));
  }

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final isLivree = _livraison.statut == 'LIVREE';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_livraison.articleTitre ?? 'Livraison active',
            style: const TextStyle(fontSize: 15)),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLivree ? Colors.green : AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_livraison.statutLabel,
                style: TextStyle(
                    color: isLivree ? Colors.white : AppColors.gold,
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Carte Google Maps ──
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : (_livraison.latVendeur != null
                            ? LatLng(_livraison.latVendeur!, _livraison.lonVendeur!)
                            : const LatLng(14.7167, -17.4677)), // Dakar par défaut
                    zoom: 14,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  onMapCreated: (ctrl) {
                    _mapController = ctrl;
                    if (_currentPosition != null) {
                      ctrl.animateCamera(CameraUpdate.newLatLng(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
                    }
                  },
                ),
                // Bouton recentrer
                Positioned(
                  bottom: 12, right: 12,
                  child: FloatingActionButton.small(
                    onPressed: () {
                      if (_currentPosition != null) {
                        _mapController?.animateCamera(CameraUpdate.newLatLng(
                            LatLng(_currentPosition!.latitude, _currentPosition!.longitude)));
                      }
                    },
                    backgroundColor: AppColors.deepPurple,
                    child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // ── Panel infos + actions ──
          Expanded(
            flex: 5,
            child: Container(
              color: bgColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: isLivree
                    ? _buildDoneView(textColor, secColor, cardColor)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        // Adresses
                        _buildAddressesCard(cardColor, textColor, secColor),
                        const SizedBox(height: 12),
                        // Étapes de progression
                        _buildProgressStepper(textColor, secColor),
                        const SizedBox(height: 12),
                        // Bouton action principale
                        _buildActionButton(),
                        if (_showValidationPanel) ...[
                          const SizedBox(height: 12),
                          _buildValidationPanel(cardColor, textColor, secColor),
                        ],
                      ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADRESSES ──

  Widget _buildAddressesCard(Color cardColor, Color textColor, Color secColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        _addressRow(Icons.store_outlined, 'Collecte chez vendeur',
            _livraison.adresseCollecte ?? 'Adresse non renseignée',
            Colors.orange, secColor, _livraison.vendeur),
        Divider(height: 20, color: Colors.grey.withValues(alpha: 0.2)),
        _addressRow(Icons.home_outlined, 'Livraison à l\'acheteur',
            _livraison.adresseLivraison ?? 'Adresse non renseignée',
            Colors.green, secColor, _livraison.acheteur),
      ]),
    );
  }

  Widget _addressRow(IconData icon, String label, String address,
      Color color, Color secColor, Map<String, dynamic>? person) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: secColor, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(address, style: TextStyle(color: secColor, fontSize: 12), maxLines: 2,
            overflow: TextOverflow.ellipsis),
        if (person != null)
          Text('${person['nom']} • ${person['phone']}',
              style: const TextStyle(color: AppColors.gold, fontSize: 11,
                  fontWeight: FontWeight.w600)),
      ])),
    ]);
  }

  // ── STEPPER PROGRESSION ──

  Widget _buildProgressStepper(Color textColor, Color secColor) {
    final etapes = [
      ('EN_ROUTE_COLLECTE', '🛵 En route collecte'),
      ('COLLECTE', '📦 Colis récupéré'),
      ('EN_ROUTE_LIVRAISON', '🚀 En route livraison'),
      ('LIVREE', '✅ Livré'),
    ];
    final statutOrder = ['ACCEPTEE', 'EN_ROUTE_COLLECTE', 'COLLECTE',
        'EN_ROUTE_LIVRAISON', 'LIVREE'];
    final currentIdx = statutOrder.indexOf(_livraison.statut);

    return Row(
      children: List.generate(etapes.length, (i) {
        final statutEtape = etapes[i].$1;
        final etapeIdx = statutOrder.indexOf(statutEtape);
        final isDone = currentIdx >= etapeIdx;
        final isCurrent = currentIdx == etapeIdx - 1;

        return Expanded(
          child: Column(children: [
            Row(children: [
              if (i > 0) Expanded(child: Container(
                  height: 2,
                  color: isDone ? AppColors.gold : Colors.grey.withValues(alpha: 0.3))),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.gold
                      : isCurrent ? AppColors.deepPurple.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? AppColors.gold
                        : isCurrent ? AppColors.deepPurple
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: isDone ? 14 : 8,
                  color: isDone ? Colors.white
                      : isCurrent ? AppColors.deepPurple
                      : Colors.grey.withValues(alpha: 0.4),
                ),
              ),
              if (i < etapes.length - 1) Expanded(child: Container(
                  height: 2,
                  color: currentIdx > etapeIdx
                      ? AppColors.gold : Colors.grey.withValues(alpha: 0.3))),
            ]),
            const SizedBox(height: 4),
            Text(etapes[i].$2.split(' ').last,
                style: TextStyle(
                    fontSize: 9,
                    color: isDone ? AppColors.gold : Colors.grey,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal),
                textAlign: TextAlign.center),
          ]),
        );
      }),
    );
  }

  // ── BOUTON ACTION PRINCIPALE ──

  Widget _buildActionButton() {
    String? actionLabel;
    String? actionKey;
    Color btnColor = AppColors.deepPurple;

    switch (_livraison.statut) {
      case 'ACCEPTEE':
        actionLabel = '🛵 Partir vers le vendeur';
        actionKey = 'EN_ROUTE_COLLECTE';
        break;
      case 'EN_ROUTE_COLLECTE':
        actionLabel = '📦 Confirmer collecte du colis';
        actionKey = 'COLLECTE';
        btnColor = Colors.orange;
        break;
      case 'COLLECTE':
        actionLabel = '🚀 Partir vers l\'acheteur';
        actionKey = 'EN_ROUTE_LIVRAISON';
        break;
      case 'EN_ROUTE_LIVRAISON':
        actionLabel = '✅ Procéder à la validation';
        break;
    }

    if (actionLabel == null) return const SizedBox.shrink();

    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () {
          if (actionKey != null) {
            _executeAction(actionKey);
          } else {
            // Ouvrir panel validation
            setState(() => _showValidationPanel = !_showValidationPanel);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text(actionLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── PANEL VALIDATION (QR / OTP + Photo) ──

  Widget _buildValidationPanel(Color cardColor, Color textColor, Color secColor) {
    final isIndirect = _livraison.typeLivraison == 'INDIRECTE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Valider la livraison', style: TextStyle(
            color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(isIndirect
            ? 'Demandez le code OTP au receveur'
            : 'Scannez le QR code de l\'acheteur',
            style: TextStyle(color: secColor, fontSize: 12)),
        const SizedBox(height: 14),

        // Photo obligatoire
        GestureDetector(
          onTap: _prendrePhoto,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: _photoPreuve != null
                  ? Colors.transparent
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _photoPreuve != null ? AppColors.gold : Colors.grey.shade400,
                  width: 1.5),
            ),
            child: _photoPreuve != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_photoPreuve!, fit: BoxFit.cover, width: double.infinity))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_outlined, size: 30, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    const Text('📸 Photo du colis livré (obligatoire)',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
          ),
        ),
        const SizedBox(height: 12),

        if (_isUploading)
          const Center(child: CircularProgressIndicator(color: AppColors.gold))
        else
          Row(children: [
            if (!isIndirect)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _validerParQr,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scanner QR', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (isIndirect)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _validerParOtp,
                  icon: const Icon(Icons.pin, size: 18),
                  label: const Text('Saisir OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }

  // ── VUE "LIVRAISON TERMINÉE" ──

  Widget _buildDoneView(Color textColor, Color secColor, Color cardColor) {
    return Column(children: [
      const SizedBox(height: 20),
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle, size: 50, color: Colors.green),
      ),
      const SizedBox(height: 16),
      Text('Livraison effectuée ! ✅',
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Cette livraison a été validée avec succès.\nMerci pour votre service !',
          style: TextStyle(color: secColor, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          _doneRow('Article', _livraison.articleTitre ?? '-', textColor, secColor),
          _doneRow('Acheteur', _livraison.acheteur?['nom'] ?? '-', textColor, secColor),
          _doneRow('Montant', _livraison.montantLivraison != null
              ? '${_livraison.montantLivraison!.toStringAsFixed(0)} FCFA' : '-',
              textColor, AppColors.gold),
        ]),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Retour au dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _doneRow(String label, String value, Color textColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

// ── QR CODE SCANNER ──

/// Écran scanner QR code.
/// Retourne le token scanné via Navigator.pop.
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner le QR code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          // Cadre de scan
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: const Center(
              child: Text('Pointez le QR code de l\'acheteur',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
