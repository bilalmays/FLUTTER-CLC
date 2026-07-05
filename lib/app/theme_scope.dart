import 'package:flutter/material.dart';

class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    required this.themeMode,
    required this.toggleTheme,
    required super.child,
    super.key,
  });

  final ThemeMode themeMode;
  final VoidCallback toggleTheme;

  bool get isLight => themeMode == ThemeMode.light;

  static AppThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope is missing from the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) {
    return themeMode != oldWidget.themeMode ||
        toggleTheme != oldWidget.toggleTheme;
  }
}
