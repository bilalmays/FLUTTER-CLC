enum AuthRole {
  admin,
  user;

  static AuthRole? fromJson(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'admin' => AuthRole.admin,
      'user' => AuthRole.user,
      _ => null,
    };
  }

  String toJson() => name;
}

class AuthSession {
  const AuthSession({
    required this.isAuthenticated,
    this.role,
    this.username,
    this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.issuedAt,
    this.expiresAt,
    this.localOnly = false,
  });

  const AuthSession.signedOut()
    : isAuthenticated = false,
      role = null,
      username = null,
      accessToken = null,
      refreshToken = null,
      tokenType = 'Bearer',
      issuedAt = null,
      expiresAt = null,
      localOnly = false;

  final bool isAuthenticated;
  final AuthRole? role;
  final String? username;
  final String? accessToken;
  final String? refreshToken;
  final String tokenType;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final bool localOnly;

  bool get isAdmin => isAuthenticated && role == AuthRole.admin && !isExpired;

  bool get isExpired {
    final limit = expiresAt;
    if (limit == null) return false;
    return !DateTime.now().toUtc().isBefore(limit.toUtc());
  }

  bool expiresWithin(Duration duration) {
    final limit = expiresAt;
    if (limit == null) return false;
    return DateTime.now().toUtc().add(duration).isAfter(limit.toUtc());
  }

  bool get hasUsableAccessToken {
    final token = accessToken?.trim();
    return isAuthenticated && token != null && token.isNotEmpty && !isExpired;
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      isAuthenticated: json['isAuthenticated'] as bool? ?? false,
      role: AuthRole.fromJson(json['role']),
      username: json['username'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      issuedAt: _dateFromJson(json['issuedAt']),
      expiresAt: _dateFromJson(json['expiresAt']),
      localOnly: json['localOnly'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'isAuthenticated': isAuthenticated,
    'role': role?.toJson(),
    'username': username,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': tokenType,
    'issuedAt': issuedAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'localOnly': localOnly,
  };

  AuthSession copyWith({
    bool? isAuthenticated,
    AuthRole? role,
    String? username,
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    DateTime? issuedAt,
    DateTime? expiresAt,
    bool? localOnly,
  }) {
    return AuthSession(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      username: username ?? this.username,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      localOnly: localOnly ?? this.localOnly,
    );
  }
}

DateTime? _dateFromJson(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
