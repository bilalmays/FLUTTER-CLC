import 'package:car_luxe_cleaning_flutter/app/constants.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/data/secure_auth_storage.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => LocalCodeAuthRepository(),
);

abstract class AuthRepository {
  Future<AuthSession> restore();
  Future<AuthSession?> currentSession();
  Future<AuthSession> login(String code);
  Future<void> logout();
}

class LocalCodeAuthRepository implements AuthRepository {
  LocalCodeAuthRepository({
    SecureAuthStorage? secureStorage,
    FlutterSecureStorage? storage,
  }) : _secureStorage = secureStorage ?? SecureAuthStorage(storage: storage);

  static const _maxFailedLoginAttempts = 5;
  static const _loginLockDuration = Duration(minutes: 1);
  static const _localSessionDuration = Duration(hours: 12);

  final SecureAuthStorage _secureStorage;
  int _failedLoginAttempts = 0;
  DateTime? _loginLockedUntil;
  AuthSession? _cachedSession;

  @override
  Future<AuthSession> restore() async {
    final session = await _secureStorage.readSession();
    _cachedSession = session;
    return session ?? const AuthSession.signedOut();
  }

  @override
  Future<AuthSession?> currentSession() async {
    final cached = _cachedSession;
    if (cached != null && cached.isAuthenticated && !cached.isExpired) {
      return cached;
    }
    final restored = await _secureStorage.readSession();
    _cachedSession = restored;
    return restored;
  }

  @override
  Future<AuthSession> login(String code) async {
    final now = DateTime.now().toUtc();
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

    // The TypeScript app only has a local Zustand role gate, not a backend JWT.
    // Keep that behavior compatible, but do not mint a fake token. Replace this
    // block with a real backend auth call when the API exposes login/refresh.
    final session = AuthSession(
      isAuthenticated: true,
      role: AuthRole.admin,
      username: 'Interne',
      issuedAt: now,
      expiresAt: now.add(_localSessionDuration),
      localOnly: true,
    );
    await _secureStorage.writeSession(session);
    _cachedSession = session;
    return session;
  }

  @override
  Future<void> logout() async {
    _cachedSession = null;
    await _secureStorage.clear();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
