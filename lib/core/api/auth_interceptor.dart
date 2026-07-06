import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:dio/dio.dart';

typedef AuthSessionReader = Future<AuthSession?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._readSession);

  final AuthSessionReader _readSession;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = await _readSession();
    if (session != null && session.hasUsableAccessToken) {
      options.headers['Authorization'] =
          '${session.tokenType} ${session.accessToken!.trim()}';
    }
    handler.next(options);
  }
}
