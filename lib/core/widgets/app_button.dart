import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
    final colors = ClcThemeColors.of(context);
    final variant = switch (tone) {
      AppButtonTone.primary => FButtonVariant.primary,
      AppButtonTone.secondary => FButtonVariant.secondary,
      AppButtonTone.ghost => FButtonVariant.ghost,
    };

    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
      child: FButton(
        onPress: onPressed,
        variant: variant,
        size: FButtonSizeVariant.lg,
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        prefix: Icon(icon ?? Icons.check_rounded, size: 18),
        child: Text(
          label.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tone == AppButtonTone.primary ? colors.onFocus : colors.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}
