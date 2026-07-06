import 'package:car_luxe_cleaning_flutter/core/config/environment.dart';
import 'package:car_luxe_cleaning_flutter/core/api/auth_interceptor.dart';
import 'package:car_luxe_cleaning_flutter/core/api/error_handler.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return ApiClient(authSessionReader: authRepository.currentSession);
});

class ApiClient {
  ApiClient({Dio? dio, AuthSessionReader? authSessionReader})
    : _dio = dio ?? _createDio() {
    if (authSessionReader != null) {
      _dio.interceptors.add(AuthInterceptor(authSessionReader));
    }
  }

  final Dio _dio;

  static Dio _createDio() {
    return Dio(
      BaseOptions(
        baseUrl: Environment.apiBaseUrl,
        connectTimeout: const Duration(seconds: 18),
        receiveTimeout: const Duration(seconds: 35),
        sendTimeout: const Duration(seconds: 35),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _dio.get<T>(path, queryParameters: query);
    } on DioException catch (error) {
      throw ErrorHandler.fromDio(error);
    }
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (error) {
      throw ErrorHandler.fromDio(error);
    }
  }
}
