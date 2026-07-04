class AuthSession {
  const AuthSession({required this.isAuthenticated, this.role, this.username});

  final bool isAuthenticated;
  final String? role;
  final String? username;
}
