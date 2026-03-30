import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show AuthProvider;
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/location_service.dart';
import '../../utils/app_logger.dart';
import 'dashboard_tab.dart';
import 'available_deliveries_tab.dart';
import 'history_tab.dart';
import 'profile_tab.dart';
import 'carte_livreurs_tab.dart';

/// Écran principal avec navigation par onglets (BottomNavigationBar).
/// 3 onglets : Dashboard | Historique | Profil
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _positionHeartbeat;
  bool _authListenerAttached = false;
  AuthProvider? _authProvider;
  final ApiClient _api = ApiClient();
  final LocationService _locationService = LocationService();
  final GlobalKey<DashboardTabState> _dashboardKey = GlobalKey<DashboardTabState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider ??= context.read<AuthProvider>();
    if (!_authListenerAttached) {
      _authListenerAttached = true;
      _authProvider!.addListener(_onAuthOrDisponibiliteChanged);
      _onAuthOrDisponibiliteChanged();
    }
  }

  void _onAuthOrDisponibiliteChanged() {
    _positionHeartbeat?.cancel();
    _positionHeartbeat = null;
    final livreur = _authProvider?.livreur;
    if (livreur == null || !livreur.disponible) {
      AppLogger.log('[Home] Heartbeat position: arrêt (hors ligne)');
      return;
    }
    AppLogger.log('[Home] Heartbeat position: toutes les 5 min');
    _sendPositionOnce();
    _positionHeartbeat = Timer.periodic(const Duration(minutes: 5), (_) => _sendPositionOnce());
  }

  Future<void> _sendPositionOnce() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos == null) return;
    try {
      await _api.put('/api/livreur/position', data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
    } catch (e) {
      AppLogger.error('[Home] PUT position', e);
    }
  }

  @override
  void dispose() {
    _positionHeartbeat?.cancel();
    if (_authListenerAttached) {
      _authProvider?.removeListener(_onAuthOrDisponibiliteChanged);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthProvider>().refreshProfile();
      _dashboardKey.currentState?.refreshActives();
    }
  }

  late final List<Widget> _tabs = [
    DashboardTab(key: _dashboardKey),
    const AvailableDeliveriesTab(),
    const CarteLivreursTab(),
    const HistoryTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i == 0) {
            _dashboardKey.currentState?.refreshActives();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.deepPurple,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Disponibles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
