import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Client HTTP centralisé pour toutes les requêtes API Trezor Backend.
/// Injecte automatiquement le JWT livreur dans chaque requête.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static String get baseUrl => AppConfig.apiBaseUrl;

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;
  bool _initialized = false;

  /// Initialise le client Dio avec intercepteur JWT.
  Future<void> init() async {
    if (_initialized) return;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
    ));

    // Intercepteur : ajouter le Bearer token à chaque requête
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'livreur_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        AppLogger.log('[API] ${options.method} ${options.path}');
        return handler.next(options);
      },
      onError: (error, handler) {
        AppLogger.error('[API] ${error.response?.statusCode} ${error.requestOptions.path}', error.message);
        return handler.next(error);
      },
    ));
    _initialized = true;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    await init();
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data}) async {
    await init();
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data, Options? options}) async {
    await init();
    return _dio.put(path, data: data, options: options);
  }

  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    await init();
    return _dio.delete(path, queryParameters: queryParameters);
  }

  /// Upload de fichier (KYC docs, preuves photo)
  Future<Response> uploadFile(String path, FormData formData) async {
    await init();
    return _dio.post(path, data: formData,
        options: Options(contentType: 'multipart/form-data'));
  }
}
