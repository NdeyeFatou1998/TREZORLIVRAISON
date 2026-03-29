import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/livreur_positions_websocket_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

/// Carte des livreurs disponibles — positions mises à jour via WebSocket (~10 s).
class CarteLivreursTab extends StatefulWidget {
  const CarteLivreursTab({super.key});

  @override
  State<CarteLivreursTab> createState() => _CarteLivreursTabState();
}

class _CarteLivreursTabState extends State<CarteLivreursTab> {
  final LivreurPositionsWebSocketService _ws = LivreurPositionsWebSocketService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  LatLng? _self;
  List<Map<String, dynamic>> _others = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pos = await _locationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _self = pos != null ? LatLng(pos.latitude, pos.longitude) : const LatLng(14.7, -17.4);
        _loading = false;
      });
    }

    _ws.onPositions = (list) {
      if (!mounted) return;
      final myId = context.read<AuthProvider>().livreur?.id;
      setState(() {
        _others = list.where((m) => m['id']?.toString() != myId).toList();
      });
    };
    await _ws.connect();

    if (_mapController != null && _self != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_self!, 12));
    }
  }

  @override
  void dispose() {
    _ws.onPositions = null;
    _ws.disconnect();
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers() {
    final out = <Marker>{};
    if (_self != null) {
      out.add(Marker(
        markerId: const MarkerId('self'),
        position: _self!,
        infoWindow: const InfoWindow(title: 'Ma position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ));
    }
    for (final m in _others) {
      final id = m['id']?.toString() ?? '';
      final lat = (m['lat'] as num?)?.toDouble();
      final lon = (m['lon'] as num?)?.toDouble();
      if (lat == null || lon == null || id.isEmpty) continue;
      final name = '${m['prenom'] ?? ''} ${m['nom'] ?? ''}'.trim();
      out.add(Marker(
        markerId: MarkerId('liv_$id'),
        position: LatLng(lat, lon),
        infoWindow: InfoWindow(title: name.isEmpty ? 'Livreur' : name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final center = _self ?? const LatLng(14.7, -17.4);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Livreurs à proximité'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () async {
              final p = await _locationService.getCurrentPosition();
              if (p != null && mounted) {
                setState(() => _self = LatLng(p.latitude, p.longitude));
                _mapController?.animateCamera(CameraUpdate.newLatLng(_self!));
              }
            },
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Positions mises à jour en temps réel (≈10 s). Les autres livreurs disponibles apparaissent en orange.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 12),
              markers: _buildMarkers(),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              onMapCreated: (c) {
                _mapController = c;
                if (_self != null) {
                  c.animateCamera(CameraUpdate.newLatLngZoom(_self!, 12));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
