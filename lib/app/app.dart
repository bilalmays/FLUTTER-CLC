import 'package:car_luxe_cleaning_flutter/app/constants.dart';
import 'package:car_luxe_cleaning_flutter/app/router.dart';
import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/app/theme_scope.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/data/auth_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_login_page.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CarLuxeCleaningApp extends StatefulWidget {
  const CarLuxeCleaningApp({super.key});

  @override
  State<CarLuxeCleaningApp> createState() => _CarLuxeCleaningAppState();
}

class _CarLuxeCleaningAppState extends State<CarLuxeCleaningApp> {
  static const _themeStorageKey = 'clc-theme-mode';

  final AuthRepository _authRepository = LocalCodeAuthRepository();
  AuthSession? _session;
  bool _restoring = true;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final results = await Future.wait<Object?>([
      _authRepository.restore(),
      SharedPreferences.getInstance(),
    ]);
    final session = results[0] as AuthSession?;
    final prefs = results[1] as SharedPreferences;
    final savedTheme = prefs.getString(_themeStorageKey);
    if (!mounted) return;
    setState(() {
      _session = session;
      _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
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

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    setState(() => _themeMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeStorageKey,
      next == ThemeMode.light ? 'light' : 'dark',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return _AppThemeShell(
        themeMode: _themeMode,
        toggleTheme: _toggleTheme,
        home: const AuthLoadingPage(),
      );
    }

    final session = _session;
    if (session == null || !session.isAuthenticated) {
      return _AppThemeShell(
        themeMode: _themeMode,
        toggleTheme: _toggleTheme,
        home: AuthLoginPage(onLogin: _login),
      );
    }

    return AppThemeScope(
      themeMode: _themeMode,
      toggleTheme: _toggleTheme,
      child: AuthScope(
        session: session,
        logout: _logout,
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}

class _AppThemeShell extends StatelessWidget {
  const _AppThemeShell({
    required this.themeMode,
    required this.toggleTheme,
    required this.home,
  });

  final ThemeMode themeMode;
  final VoidCallback toggleTheme;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      themeMode: themeMode,
      toggleTheme: toggleTheme,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: home,
      ),
    );
  }
}
