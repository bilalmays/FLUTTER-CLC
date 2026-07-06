import 'package:car_luxe_cleaning_flutter/core/errors/app_exception.dart';
import 'package:dio/dio.dart';

class ApiException extends AppException {
  const ApiException(super.message, {super.cause, this.statusCode, this.code});

  final int? statusCode;
  final String? code;
}

class ErrorHandler {
  const ErrorHandler._();

  static AppException fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = _messageFromPayload(error.response?.data);
    if (message != null) {
      return ApiException(message, cause: error, statusCode: statusCode);
    }

    return ApiException(
      _fallbackMessage(error, statusCode),
      cause: error,
      statusCode: statusCode,
    );
  }

  static String? _messageFromPayload(Object? payload) {
    if (payload is Map<String, dynamic>) {
      final direct = payload['error'] ?? payload['message'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      final nested = payload['details'];
      if (nested is Map<String, dynamic>) {
        final nestedMessage = nested['message'];
        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          return nestedMessage.trim();
        }
      }
    }
    if (payload is String && payload.trim().isNotEmpty) {
      return payload.trim();
    }
    return null;
  }

  static String _fallbackMessage(DioException error, int? statusCode) {
    if (statusCode == 401) {
      return 'Session expiree. Reconnecte-toi.';
    }
    if (statusCode == 403) {
      return 'Acces refuse.';
    }
    if (statusCode == 404) {
      return 'Ressource introuvable.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Le serveur est temporairement indisponible.';
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'La connexion a expire.',
      DioExceptionType.connectionError => 'Connexion reseau indisponible.',
      DioExceptionType.cancel => 'Requete annulee.',
      _ => 'Une erreur reseau est survenue.',
    };
  }
}
