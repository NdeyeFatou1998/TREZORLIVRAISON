import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Config runtime : --dart-define prioritaire, puis .env local (jamais dans l'APK).
class AppConfig {
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['API_BASE_URL']?.trim().isNotEmpty == true
        ? dotenv.env['API_BASE_URL']!.trim()
        : 'https://trezorbackend-production.up.railway.app';
  }

  static String get googleMapsApiKey {
    const fromDefine = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    const geoDefine = String.fromEnvironment('GOOGLE_GEOLOCATION_API_KEY');
    if (geoDefine.isNotEmpty) return geoDefine;
    final a = dotenv.env['GOOGLE_MAPS_API_KEY']?.trim();
    if (a != null && a.isNotEmpty) return a;
    return dotenv.env['GOOGLE_GEOLOCATION_API_KEY']?.trim() ?? '';
  }
}
