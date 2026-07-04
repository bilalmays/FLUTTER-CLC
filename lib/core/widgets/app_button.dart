import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:flutter/material.dart';

enum AppButtonTone { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.tone = AppButtonTone.primary,
    this.expanded = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonTone tone;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isPrimary = tone == AppButtonTone.primary;
    final background = isPrimary
        ? AppColors.accent
        : tone == AppButtonTone.secondary
        ? AppColors.surfaceMuted
        : Colors.transparent;
    final foreground = isPrimary ? AppColors.ink : AppColors.text;
    final borderColor = tone == AppButtonTone.ghost
        ? Colors.transparent
        : AppColors.border;

    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.surfaceMuted,
          disabledForegroundColor: AppColors.muted,
          elevation: isPrimary ? 10 : 0,
          shadowColor: isPrimary
              ? AppColors.accent.withValues(alpha: 0.22)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_rounded, size: 18),
        label: Text(label.toUpperCase()),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}
