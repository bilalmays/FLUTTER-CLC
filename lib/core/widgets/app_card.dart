import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.color,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClcThemeColors.of(context);
    final foruiCard = FTheme.of(context).cardStyle;
    final card = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: FCard(
        style: FCardStyle(
          decoration: BoxDecoration(
            color: color ?? colors.field,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor ?? colors.border),
            boxShadow: colors.isLight ? AppShadows.soft : const [],
          ),
          titleTextStyle: foruiCard.titleTextStyle,
          subtitleTextStyle: foruiCard.subtitleTextStyle,
          padding: EdgeInsets.zero,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
