import 'dart:convert';

import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAuthStorage {
  SecureAuthStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static const _sessionKey = 'car_luxe_cleaning.auth.session.v1';
  static const _defaultStorage = FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<AuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid auth session payload.');
      }
      final session = AuthSession.fromJson(decoded);
      if (!session.isAuthenticated || session.isExpired) {
        await clear();
        return null;
      }
      return session;
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> writeSession(AuthSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> clear() => _storage.delete(key: _sessionKey);
}
