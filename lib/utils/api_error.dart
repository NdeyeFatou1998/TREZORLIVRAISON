import 'package:dio/dio.dart';

/// Erreur API TREZO : message français clair + code machine (ex. LIV_004).
class ApiError implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;

  const ApiError({
    required this.message,
    this.errorCode,
    this.statusCode,
  });

  factory ApiError.fromDio(DioException e) {
    final data = e.response?.data;
    String message = 'Erreur réseau. Vérifiez votre connexion.';
    String? code;
    if (data is Map) {
      final m = data['message']?.toString();
      if (m != null && m.trim().isNotEmpty) message = m.trim();
      final c = data['errorCode']?.toString();
      if (c != null && c.trim().isNotEmpty) code = c.trim();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = 'Délai dépassé. Réessayez dans un instant.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Impossible de joindre le serveur TREZO.';
    }
    return ApiError(
      message: message,
      errorCode: code,
      statusCode: e.response?.statusCode,
    );
  }

  factory ApiError.fromResponseBody(dynamic data, {int? statusCode}) {
    if (data is Map) {
      final m = data['message']?.toString();
      final c = data['errorCode']?.toString();
      return ApiError(
        message: (m != null && m.trim().isNotEmpty)
            ? m.trim()
            : 'Une erreur est survenue.',
        errorCode: (c != null && c.trim().isNotEmpty) ? c.trim() : null,
        statusCode: statusCode,
      );
    }
    return ApiError(
      message: 'Une erreur est survenue.',
      statusCode: statusCode,
    );
  }

  /// Message affichable (SnackBar / dialog).
  static String messageOf(Object error) {
    if (error is ApiError) return error.message;
    if (error is DioException) return ApiError.fromDio(error).message;
    final s = error.toString();
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  @override
  String toString() => message;
}
