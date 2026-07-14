import 'package:flutter/material.dart';

@immutable
class ClcThemeColors extends ThemeExtension<ClcThemeColors> {
  const ClcThemeColors({
    required this.isLight,
    required this.bg,
    required this.shell,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceRaised,
    required this.field,
    required this.text,
    required this.textStrong,
    required this.muted,
    required this.mutedStrong,
    required this.border,
    required this.borderStrong,
    required this.focus,
    required this.onFocus,
    required this.action,
    required this.onAction,
    required this.danger,
  });

  final bool isLight;
  final Color bg;
  final Color shell;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceRaised;
  final Color field;
  final Color text;
  final Color textStrong;
  final Color muted;
  final Color mutedStrong;
  final Color border;
  final Color borderStrong;
  final Color focus;
  final Color onFocus;
  final Color action;
  final Color onAction;
  final Color danger;

  static const dark = ClcThemeColors(
    isLight: false,
    bg: Color(0xFF050505),
    shell: Color(0xFF0A0A0A),
    surface: Color(0xFF1F1F1F),
    surfaceSoft: Color(0xFF161616),
    surfaceRaised: Color(0xFF232323),
    field: Color(0x0AFFFFFF),
    text: Color(0xFFF4F4F5),
    textStrong: Color(0xFFFAFAFA),
    muted: Color(0xFFA1A1AA),
    mutedStrong: Color(0xFF71717A),
    border: Color(0x1AFFFFFF),
    borderStrong: Color(0xFF46464A),
    focus: Color(0xFFAFF700),
    onFocus: Color(0xFF050505),
    action: Color(0xFFF4F4F5),
    onAction: Color(0xFF050505),
    danger: Color(0xFFFB7185),
  );

  static const light = ClcThemeColors(
    isLight: true,
    bg: Color(0xFFE5E7EB),
    shell: Color(0xFFECEFF3),
    surface: Color(0xFFF4F4F5),
    surfaceSoft: Color(0xFFF4F4F5),
    surfaceRaised: Color(0xFFFFFFFF),
    field: Color(0xFFFFFFFF),
    text: Color(0xFF17191D),
    textStrong: Color(0xFF0B0C0F),
    muted: Color(0xFF555B66),
    mutedStrong: Color(0xFF444B56),
    border: Color(0xFFE4E4E7),
    borderStrong: Color(0xFFD1D5DB),
    focus: Color(0xFF0B0C0F),
    onFocus: Color(0xFFF4F6F8),
    action: Color(0xFF0B0C0F),
    onAction: Color(0xFFF4F6F8),
    danger: Color(0xFF8F1D24),
  );

  static ClcThemeColors of(BuildContext context) {
    return Theme.of(context).extension<ClcThemeColors>() ??
        (Theme.of(context).brightness == Brightness.light ? light : dark);
  }

  @override
  ClcThemeColors copyWith({
    bool? isLight,
    Color? bg,
    Color? shell,
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceRaised,
    Color? field,
    Color? text,
    Color? textStrong,
    Color? muted,
    Color? mutedStrong,
    Color? border,
    Color? borderStrong,
    Color? focus,
    Color? onFocus,
    Color? action,
    Color? onAction,
    Color? danger,
  }) {
    return ClcThemeColors(
      isLight: isLight ?? this.isLight,
      bg: bg ?? this.bg,
      shell: shell ?? this.shell,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      field: field ?? this.field,
      text: text ?? this.text,
      textStrong: textStrong ?? this.textStrong,
      muted: muted ?? this.muted,
      mutedStrong: mutedStrong ?? this.mutedStrong,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      focus: focus ?? this.focus,
      onFocus: onFocus ?? this.onFocus,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      danger: danger ?? this.danger,
    );
  }

  @override
  ClcThemeColors lerp(ThemeExtension<ClcThemeColors>? other, double t) {
    if (other is! ClcThemeColors) return this;
    return ClcThemeColors(
      isLight: t < 0.5 ? isLight : other.isLight,
      bg: Color.lerp(bg, other.bg, t)!,
      shell: Color.lerp(shell, other.shell, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      field: Color.lerp(field, other.field, t)!,
      text: Color.lerp(text, other.text, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedStrong: Color.lerp(mutedStrong, other.mutedStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      onFocus: Color.lerp(onFocus, other.onFocus, t)!,
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

class AppColors {
  const AppColors._();

  static const navy = Color(0xFF0F172A);
  static const ink = Color(0xFF030712);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFFCBD5E1);
  static const background = Color(0xFF090B17);
  static const surface = Color(0xFF111827);
  static const surfaceMuted = Color(0xFF0F172A);
  static const surfaceRaised = Color(0xFF1E293B);
  static const gold = Color(0xFFEAB308);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const accent = Color(0xFF818CF8);
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
    letterSpacing: 3.2,
    color: AppColors.muted,
  );

  static const pageTitle = TextStyle(
    fontSize: 42,
    height: 1.05,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.text,
  );

  static const cardTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.text,
  );

  static const sectionTitle = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  static const label = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.4,
    color: AppColors.muted,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return _build(ClcThemeColors.light, Brightness.light);
  }

  static ThemeData dark() {
    return _build(ClcThemeColors.dark, Brightness.dark);
  }

  static ThemeData _build(ClcThemeColors colors, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.focus,
        brightness: brightness,
        surface: colors.surface,
        primary: colors.focus,
        onPrimary: colors.onFocus,
        onSurface: colors.text,
      ),
      scaffoldBackgroundColor: colors.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.shell,
        surfaceTintColor: colors.shell,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.cardTitle.copyWith(color: colors.textStrong),
        iconTheme: IconThemeData(color: colors.textStrong),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceRaised,
        elevation: 14,
        shadowColor: colors.focus.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.focus,
          foregroundColor: colors.onFocus,
          disabledBackgroundColor: colors.surfaceSoft,
          disabledForegroundColor: colors.muted,
          elevation: 14,
          shadowColor: colors.focus.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.surfaceSoft,
          foregroundColor: colors.textStrong,
          disabledBackgroundColor: colors.surfaceSoft,
          disabledForegroundColor: colors.muted,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.6),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.focus,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardColor: colors.surfaceRaised,
      canvasColor: colors.shell,
      iconTheme: IconThemeData(color: colors.text, size: 22),
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        bodyColor: colors.text,
        displayColor: colors.text,
        fontFamily: 'Inter',
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSoft,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.focus, width: 1.6),
          borderRadius: BorderRadius.circular(18),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 18,
        ),
        labelStyle: AppTextStyles.label.copyWith(color: colors.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceRaised,
        contentTextStyle: TextStyle(color: colors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 28),
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }
}
