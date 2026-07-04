import 'package:car_luxe_cleaning_flutter/core/config/environment.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Environment.apiBaseUrl,
              connectTimeout: const Duration(seconds: 18),
              receiveTimeout: const Duration(seconds: 35),
              headers: {'Content-Type': 'application/json'},
            ),
          );

  final Dio _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) {
    return _dio.get<T>(path, queryParameters: query);
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _dio.post<T>(path, data: data);
  }
}
