import 'dart:async';

import 'package:car_luxe_cleaning_flutter/app/constants.dart';
import 'package:car_luxe_cleaning_flutter/app/router.dart';
import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:car_luxe_cleaning_flutter/app/theme_scope.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/data/auth_repository.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/domain/auth_session.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_login_page.dart';
import 'package:car_luxe_cleaning_flutter/features/auth/presentation/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CarLuxeCleaningApp extends ConsumerStatefulWidget {
  const CarLuxeCleaningApp({super.key});

  @override
  ConsumerState<CarLuxeCleaningApp> createState() => _CarLuxeCleaningAppState();
}

class _CarLuxeCleaningAppState extends ConsumerState<CarLuxeCleaningApp> {
  static const _themeStorageKey = 'clc-theme-mode';

  late final AuthRepository _authRepository;
  AuthSession? _session;
  Timer? _sessionExpiryTimer;
  bool _restoring = true;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _authRepository = ref.read(authRepositoryProvider);
    _restoreSession();
  }

  @override
  void dispose() {
    _sessionExpiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final results = await Future.wait<Object?>([
      _authRepository.restore(),
      SharedPreferences.getInstance(),
    ]);
    final session = results[0] as AuthSession;
    final prefs = results[1] as SharedPreferences;
    final savedTheme = prefs.getString(_themeStorageKey);
    if (!mounted) return;
    _scheduleSessionExpiry(session);
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
    _scheduleSessionExpiry(session);
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    if (!mounted) return;
    _sessionExpiryTimer?.cancel();
    setState(() => _session = const AuthSession.signedOut());
  }

  void _scheduleSessionExpiry(AuthSession session) {
    _sessionExpiryTimer?.cancel();
    if (!session.isAuthenticated || session.expiresAt == null) return;

    final delay = session.expiresAt!.toUtc().difference(DateTime.now().toUtc());
    if (delay <= Duration.zero) {
      unawaited(_expireSession());
      return;
    }

    _sessionExpiryTimer = Timer(delay, () => unawaited(_expireSession()));
  }

  Future<void> _expireSession() async {
    await _authRepository.logout();
    if (!mounted) return;
    setState(() => _session = const AuthSession.signedOut());
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
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: FLocalizations.supportedLocales,
          builder: (context, child) => _DesignSystemScope(
            themeMode: _themeMode,
            child: child ?? const SizedBox.shrink(),
          ),
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
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) => _DesignSystemScope(
          themeMode: themeMode,
          child: child ?? const SizedBox.shrink(),
        ),
        home: home,
      ),
    );
  }
}

const _localizationsDelegates = [
  FLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

class _DesignSystemScope extends StatelessWidget {
  const _DesignSystemScope({required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    final isLight = brightness == Brightness.light;

    return ShadTheme(
      data: ShadThemeData(
        brightness: brightness,
        radius: BorderRadius.circular(8),
      ),
      child: FTheme(
        data: isLight ? FTheme.neutral.light.touch : FTheme.neutral.dark.touch,
        child: child,
      ),
    );
  }
}
