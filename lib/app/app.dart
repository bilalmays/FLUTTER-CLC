import 'package:car_luxe_cleaning_flutter/app/constants.dart';
import 'package:car_luxe_cleaning_flutter/app/router.dart';
import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/data/auth_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_login_page.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_scope.dart';
import 'package:flutter/material.dart';

class CarLuxeCleaningApp extends StatefulWidget {
  const CarLuxeCleaningApp({super.key});

  @override
  State<CarLuxeCleaningApp> createState() => _CarLuxeCleaningAppState();
}

class _CarLuxeCleaningAppState extends State<CarLuxeCleaningApp> {
  final AuthRepository _authRepository = LocalCodeAuthRepository();
  AuthSession? _session;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await _authRepository.restore();
    if (!mounted) return;
    setState(() {
      _session = session;
      _restoring = false;
    });
  }

  Future<void> _login(String code) async {
    final session = await _authRepository.login(code);
    if (!session.isAuthenticated) {
      throw const AuthException('Code incorrect.');
    }
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    if (!mounted) return;
    setState(() => _session = const AuthSession(isAuthenticated: false));
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return _AppThemeShell(home: const AuthLoadingPage());
    }

    final session = _session;
    if (session == null || !session.isAuthenticated) {
      return _AppThemeShell(home: AuthLoginPage(onLogin: _login));
    }

    return AuthScope(
      session: session,
      logout: _logout,
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
      ),
    );
  }
}

class _AppThemeShell extends StatelessWidget {
  const _AppThemeShell({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: home,
    );
  }
}
