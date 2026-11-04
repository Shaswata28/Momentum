import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum TagType { fixed, floating, adhoc, buffer, dnd, missed }

class TagChip extends StatelessWidget {
  final TagType type;
  final String label;

  const TagChip({super.key, required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    Color textColor = AppColors.textMuted;
    Color bgColor = Colors.white.withValues(alpha: 0.04);
    Color borderColor = Colors.white.withValues(alpha: 0.06);

    switch (type) {
      case TagType.fixed:
      case TagType.floating:
      case TagType.adhoc:
        textColor = AppColors.textSecondary;
        bgColor = Colors.white.withValues(alpha: 0.04);
        borderColor = Colors.white.withValues(alpha: 0.06);
        break;
      case TagType.buffer:
        textColor = AppColors.textPlaceholder;
        bgColor = Colors.white.withValues(alpha: 0.03);
        borderColor = Colors.white.withValues(alpha: 0.04);
        break;
      case TagType.dnd:
        textColor = AppColors.accentPrimary;
        bgColor = AppColors.accentPrimary.withValues(alpha: 0.08);
        borderColor = AppColors.accentPrimary.withValues(alpha: 0.16);
        break;
      case TagType.missed:
        textColor = AppColors.errorAlert;
        bgColor = AppColors.errorAlert.withValues(alpha: 0.08);
        borderColor = AppColors.errorAlert.withValues(alpha: 0.18);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (type == TagType.dnd) ...[
            Icon(Icons.shield_outlined, size: 10.5, color: AppColors.accentPrimary),
            const SizedBox(width: 3.5),
          ],
          Text(
            label,
            style: AppTypography.tagChip.copyWith(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
