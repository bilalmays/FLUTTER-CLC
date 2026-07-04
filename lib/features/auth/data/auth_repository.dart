import 'package:car_luxe_cleaning_flutter/app/constants.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthRepository {
  Future<AuthSession> restore();
  Future<AuthSession> login(String code);
  Future<void> logout();
}

class LocalCodeAuthRepository implements AuthRepository {
  LocalCodeAuthRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'clc_session';
  static const _maxFailedLoginAttempts = 5;
  static const _loginLockDuration = Duration(minutes: 1);

  final FlutterSecureStorage _storage;
  int _failedLoginAttempts = 0;
  DateTime? _loginLockedUntil;

  @override
  Future<AuthSession> restore() async {
    final value = await _storage.read(key: _sessionKey);
    return AuthSession(isAuthenticated: value == 'admin', role: value);
  }

  @override
  Future<AuthSession> login(String code) async {
    final now = DateTime.now();
    final lockedUntil = _loginLockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      throw const AuthException(
        'Trop de tentatives. Reessaie dans une minute.',
      );
    }

    if (code.trim() != AppConstants.accessCode.trim()) {
      _failedLoginAttempts += 1;
      if (_failedLoginAttempts >= _maxFailedLoginAttempts) {
        _failedLoginAttempts = 0;
        _loginLockedUntil = now.add(_loginLockDuration);
      }
      throw const AuthException('Code incorrect.');
    }

    _failedLoginAttempts = 0;
    _loginLockedUntil = null;
    await _storage.write(key: _sessionKey, value: 'admin');
    return const AuthSession(
      isAuthenticated: true,
      role: 'admin',
      username: 'Interne',
    );
  }

  @override
  Future<void> logout() => _storage.delete(key: _sessionKey);
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
