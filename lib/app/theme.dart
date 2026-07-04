import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const navy = Color(0xFF111827);
  static const ink = Color(0xFF050505);
  static const text = Color(0xFFF4F4F5);
  static const muted = Color(0xFFA1A1AA);
  static const border = Color(0x1AFFFFFF);
  static const background = Color(0xFF050505);
  static const surface = Color(0xFF1F1F1F);
  static const surfaceMuted = Color(0xFF161616);
  static const surfaceRaised = Color(0xFF232323);
  static const gold = Color(0xFFCA8A04);
  static const danger = Color(0xFFFB7185);
  static const success = Color(0xFF22C55E);
  static const accent = Color(0xFFAFF700);
}

class AppSpacing {
  const AppSpacing._();

  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  const AppRadius._();

  static const sm = Radius.circular(8);
  static const md = Radius.circular(8);
  static const lg = Radius.circular(8);
  static const xl = Radius.circular(8);
}

class AppShadows {
  const AppShadows._();

  static const soft = [
    BoxShadow(color: Color(0x00000000), blurRadius: 0, offset: Offset.zero),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 16)),
  ];
}

class AppTextStyles {
  const AppTextStyles._();

  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    letterSpacing: 4,
    color: AppColors.muted,
  );

  static const pageTitle = TextStyle(
    fontSize: 44,
    height: 0.95,
    fontWeight: FontWeight.w300,
    letterSpacing: 0,
    color: AppColors.text,
  );

  static const cardTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.1,
    color: AppColors.text,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: 'Inter',
      ),
      iconTheme: const IconThemeData(color: AppColors.text, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        labelStyle: AppTextStyles.eyebrow.copyWith(letterSpacing: 2),
      ),
    );
  }

  static ThemeData dark() {
    final base = light();
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF07080B),
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: const Color(0xFF17181C),
      ),
    );
  }
}
