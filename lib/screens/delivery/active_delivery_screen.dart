import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../theme/app_theme.dart';
import '../../models/livraison.dart';
import '../../services/livraison_service.dart';
import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import '../../services/directions_service.dart';

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
  final Set<Polyline> _polylines = {};
  String? _nextTurnInstruction;
  String? _routeEtaLine;
  String? _routeFetchError;
  LatLng? _lastRouteAnchor;
  DateTime? _lastRouteAt;
  int _routeGen = 0;
  Timer? _routeRefreshTimer;
  /// Évite de recentrer la carte à chaque refresh GPS (sinon itinéraire illisible).
  String? _lastFitContextKey;

  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _voiceGuidance = true;
  String? _lastSpokenInstruction;
  Timer? _ttsDebounce;

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
    _startRoutePeriodicRefresh();
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    if (!mounted) return;
    setState(() => _ttsReady = true);
  }

  void _scheduleSpeakTurnInstruction(String? instruction) {
    if (!_ttsReady || !_voiceGuidance || instruction == null || instruction.isEmpty) return;
    if (instruction == _lastSpokenInstruction) return;
    _ttsDebounce?.cancel();
    _ttsDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted || !_voiceGuidance) return;
      _lastSpokenInstruction = instruction;
      await _tts.stop();
      await _tts.speak(instruction);
    });
  }

  @override
  void dispose() {
    _ttsDebounce?.cancel();
    _tts.stop();
    _refreshTimer?.cancel();
    _routeRefreshTimer?.cancel();
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
      await _refreshDrivingRoute(pos);
    }
  }

  void _startPositionTracking() {
    _locationService.startTracking(
      distanceFilterMeters: 5,
      onPosition: (pos) async {
        if (!mounted) return;
        setState(() {
          _currentPosition = pos;
          _updateMarkers(pos.latitude, pos.longitude);
        });
        _maybeRefreshRouteFromMovement(pos);
        // Envoyer position au backend
        final h = pos.heading;
        await _livraisonService.updatePosition(
          _livraison.id,
          pos.latitude,
          pos.longitude,
          heading: h >= 0 ? h : null,
        );
      },
    );
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final updated = await _livraisonService.getSuivi(_livraison.id);
      if (updated != null && mounted) {
        final prev = _livraison.statut;
        setState(() => _livraison = updated);
        if (updated.statut != prev) {
          final p = _currentPosition;
          if (p != null) await _refreshDrivingRoute(p);
        }
      }
    });
  }

  void _startRoutePeriodicRefresh() {
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (!mounted || _livraison.isTerminee) return;
      final pos = _currentPosition;
      if (pos != null) _refreshDrivingRoute(pos);
    });
  }

  /// Destination routière : vendeur tant que le colis n’est pas récupéré, puis acheteur.
  LatLng? _navigationTarget() {
    if (_livraison.isTerminee) return null;
    final towardBuyer =
        _livraison.statut == 'COLLECTE' || _livraison.statut == 'EN_ROUTE_LIVRAISON';
    if (towardBuyer) {
      if (_livraison.latAcheteur != null && _livraison.lonAcheteur != null) {
        return LatLng(_livraison.latAcheteur!, _livraison.lonAcheteur!);
      }
      return null;
    }
    if (_livraison.latVendeur != null && _livraison.lonVendeur != null) {
      return LatLng(_livraison.latVendeur!, _livraison.lonVendeur!);
    }
    return null;
  }

  void _maybeRefreshRouteFromMovement(Position pos) {
    if (_livraison.isTerminee) return;
    final dest = _navigationTarget();
    if (dest == null) return;

    final anchor = _lastRouteAnchor;
    final lastAt = _lastRouteAt;
    final now = DateTime.now();
    var need = false;
    if (anchor == null || lastAt == null) {
      need = true;
    } else {
      final moved = Geolocator.distanceBetween(
        anchor.latitude,
        anchor.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved > 150 || now.difference(lastAt) > const Duration(seconds: 90)) {
        need = true;
      }
    }
    if (need) _refreshDrivingRoute(pos);
  }

  Future<void> _refreshDrivingRoute(Position pos) async {
    final dest = _navigationTarget();
    if (dest == null) {
      if (!mounted) return;
      setState(() {
        _polylines.clear();
        _nextTurnInstruction = null;
        _routeEtaLine = null;
        _routeFetchError = null;
      });
      _lastSpokenInstruction = null;
      return;
    }

    final id = ++_routeGen;
    final origin = LatLng(pos.latitude, pos.longitude);
    final data = await DirectionsService.fetchDrivingRoute(
      origin: origin,
      destination: dest,
    );

    if (!mounted || id != _routeGen) return;

    if (!data.isOk) {
      setState(() {
        _polylines.clear();
        _routeFetchError = data.errorMessage;
        _nextTurnInstruction = null;
        _routeEtaLine = null;
      });
      _lastSpokenInstruction = null;
      return;
    }

    setState(() {
      _routeFetchError = null;
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('itineraire'),
            color: const Color(0xFF4285F4),
            width: 6,
            points: data.points,
            geodesic: true,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      _nextTurnInstruction = data.nextInstruction;
      final parts = <String>[];
      if (data.durationRemainingText != null) {
        parts.add(data.durationRemainingText!);
      }
      if (data.distanceRemainingText != null) {
        parts.add(data.distanceRemainingText!);
      }
      _routeEtaLine = parts.isEmpty ? null : parts.join(' · ');
      _lastRouteAnchor = origin;
      _lastRouteAt = DateTime.now();
    });

    _scheduleSpeakTurnInstruction(data.nextInstruction);

    final fitKey =
        '${_livraison.statut}|${_navigationTarget()?.latitude},${_navigationTarget()?.longitude}';
    if (_lastFitContextKey != fitKey) {
      _lastFitContextKey = fitKey;
      _fitMapToRoute(data.points);
    }
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (_mapController == null) return;
    final dest = _navigationTarget();
    final rider = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;

    final all = <LatLng>[...points];
    if (rider != null) all.add(rider);
    if (dest != null) all.add(dest);

    if (all.isEmpty) return;

    if (all.length == 1) {
      if (!mounted) return;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(all.first, 15));
      return;
    }

    double minLat = all.first.latitude;
    double maxLat = minLat;
    double minLng = all.first.longitude;
    double maxLng = minLng;
    for (final p in all) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    const eps = 0.0025;
    if ((maxLat - minLat).abs() < 0.0008) {
      minLat -= eps;
      maxLat += eps;
    }
    if ((maxLng - minLng).abs() < 0.0008) {
      minLng -= eps;
      maxLng += eps;
    }

    if (!mounted) return;
    final mq = MediaQuery.of(context);
    final bottomPad = mq.size.height * 0.22 + mq.padding.bottom + 24;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        max(72.0, bottomPad * 0.85),
      ),
    );
  }

  /// Recadre sur la polyline d’itinéraire (ou segment livreur → destination).
  void _recenterOnItinerary() {
    if (_mapController == null) return;
    for (final pl in _polylines) {
      if (pl.points.isNotEmpty) {
        _fitMapToRoute(pl.points);
        return;
      }
    }
    final pos = _currentPosition;
    final dest = _navigationTarget();
    if (pos != null && dest != null) {
      _fitMapToRoute([
        LatLng(pos.latitude, pos.longitude),
        dest,
      ]);
    } else if (pos != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          15,
        ),
      );
    }
  }

  Future<void> _openExternalTurnByTurn() async {
    final dest = _navigationTarget();
    final pos = _currentPosition;
    if (dest == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${dest.latitude},${dest.longitude}'
      '&travelmode=driving'
      '${pos != null ? '&origin=${pos.latitude},${pos.longitude}' : ''}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        final p = _currentPosition;
        if (p != null) await _refreshDrivingRoute(p);
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
        title: const Text('Code à 5 chiffres'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Le receveur (intermédiaire) vous communique le code transmis par l’acheteur.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
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
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          final mapBottomPad = mq.size.height * 0.26 + mq.padding.bottom;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : (_livraison.latVendeur != null
                            ? LatLng(_livraison.latVendeur!, _livraison.lonVendeur!)
                            : const LatLng(14.7167, -17.4677)),
                    zoom: 14,
                  ),
                  padding: EdgeInsets.only(
                    top: mq.padding.top + kToolbarHeight + 8,
                    left: 10,
                    right: 10,
                    bottom: mapBottomPad,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapType: MapType.normal,
                  onMapCreated: (ctrl) {
                    _mapController = ctrl;
                  },
                ),
              ),
              Positioned(
                right: 12,
                bottom: mq.padding.bottom + mq.size.height * 0.22 + 8,
                child: FloatingActionButton.small(
                  heroTag: 'active_delivery_recenter',
                  tooltip: 'Voir l’itinéraire',
                  onPressed: _recenterOnItinerary,
                  backgroundColor: AppColors.deepPurple,
                  child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: isLivree ? 0.42 : 0.28,
                minChildSize: 0.12,
                maxChildSize: 0.92,
                snap: true,
                snapSizes: const [0.12, 0.28, 0.55, 0.92],
                builder: (context, scrollController) {
                  return Material(
                    color: cardColor,
                    elevation: 8,
                    shadowColor: Colors.black45,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 6),
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: secColor.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.drag_handle, color: secColor, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                isLivree ? 'Mission terminée' : 'Détails & étapes',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: EdgeInsets.fromLTRB(16, 0, 16, mq.padding.bottom + 16),
                            children: isLivree
                                ? [_buildDoneView(textColor, secColor, cardColor)]
                                : [
                                    if (_nextTurnInstruction != null ||
                                        _routeEtaLine != null ||
                                        _routeFetchError != null)
                                      _buildRouteSummaryCard(cardColor, textColor, secColor),
                                    if (_nextTurnInstruction != null ||
                                        _routeEtaLine != null ||
                                        _routeFetchError != null)
                                      const SizedBox(height: 12),
                                    _buildAddressesCard(cardColor, textColor, secColor),
                                    const SizedBox(height: 12),
                                    _buildProgressStepper(textColor, secColor),
                                    const SizedBox(height: 12),
                                    _buildActionButton(),
                                    if (_showValidationPanel) ...[
                                      const SizedBox(height: 12),
                                      _buildValidationPanel(cardColor, textColor, secColor),
                                    ],
                                  ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteSummaryCard(Color cardColor, Color textColor, Color secColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _routeFetchError != null ? Icons.warning_amber_rounded : Icons.turn_slight_right,
                color: _routeFetchError != null ? Colors.orange : AppColors.deepPurple,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _routeFetchError ?? _nextTurnInstruction ?? 'Itinéraire',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                tooltip: _voiceGuidance ? 'Couper le guidage vocal' : 'Activer le guidage vocal',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () {
                  setState(() {
                    _voiceGuidance = !_voiceGuidance;
                    if (!_voiceGuidance) {
                      _tts.stop();
                      _lastSpokenInstruction = null;
                    }
                  });
                },
                icon: Icon(
                  _voiceGuidance ? Icons.volume_up : Icons.volume_off,
                  color: AppColors.deepPurple,
                  size: 22,
                ),
              ),
              IconButton(
                tooltip: 'Ouvrir dans Google Maps',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: _openExternalTurnByTurn,
                icon: const Icon(Icons.navigation, color: AppColors.deepPurple, size: 22),
              ),
            ],
          ),
          if (_routeEtaLine != null && _routeFetchError == null) ...[
            const SizedBox(height: 4),
            Text(
              _routeEtaLine!,
              style: TextStyle(color: secColor, fontSize: 11.5),
            ),
          ],
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
            ? 'Demandez le code à 5 chiffres au receveur (donné par l’acheteur)'
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
                  label: const Text('Saisir le code', style: TextStyle(fontWeight: FontWeight.bold)),
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
          const Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Center(
              child: Text('Pointez le QR code de l\'acheteur',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
