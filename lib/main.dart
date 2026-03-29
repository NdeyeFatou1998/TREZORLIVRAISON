import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

/// Point d'entrée de l'application Trezor Livraison.
/// Charge les variables d'environnement (.env) puis lance l'app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const TrezorLivraisonApp());
}

/// Reste au-dessus du [MaterialApp] pour que FCM / rafraîchissement profil survivent à la navigation.
class _NotificationBootstrap extends StatefulWidget {
  const _NotificationBootstrap({required this.child});

  final Widget child;

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      NotificationService().setOnRefreshProfil(() => auth.refreshProfile());
      await NotificationService().initialize();
      await NotificationService().syncFcmTokenToBackendIfLoggedIn();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TrezorLivraisonApp extends StatelessWidget {
  const TrezorLivraisonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: _NotificationBootstrap(
        child: MaterialApp(
          title: 'Trezor Livraison',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
