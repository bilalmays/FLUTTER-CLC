import 'package:car_luxe_cleaning_flutter/app/theme.dart';
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    this.color = AppColors.surfaceMuted,
    this.textColor = AppColors.text,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: icon == null
          ? Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: textColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
