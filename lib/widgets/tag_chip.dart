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
    Color bgColor = AppColors.cardHoverActive;
    Color borderColor = AppColors.subtleBorder;

    final isRetro = AppColors.isRetro;

    switch (type) {
      case TagType.fixed:
      case TagType.floating:
      case TagType.adhoc:
        textColor = AppColors.textSecondary;
        bgColor = isRetro
            ? AppColors.cardBackground
            : AppColors.cardHoverActive;
        borderColor = isRetro ? AppColors.cardBorder : AppColors.subtleBorder;
        break;
      case TagType.buffer:
        textColor = AppColors.textSecondary;
        bgColor = AppColors.appBackground;
        borderColor = isRetro ? AppColors.cardBorder : AppColors.subtleBorder;
        break;
      case TagType.dnd:
        textColor = AppColors.textPrimary;
        bgColor = isRetro
            ? AppColors.accentPrimary.withValues(alpha: 0.18)
            : AppColors.accentPrimary.withValues(alpha: 0.08);
        borderColor = isRetro
            ? AppColors.cardBorder
            : AppColors.accentPrimary.withValues(alpha: 0.16);
        break;
      case TagType.missed:
        textColor = AppColors.textPrimary;
        bgColor = isRetro
            ? AppColors.errorAlert.withValues(alpha: 0.18)
            : AppColors.errorAlert.withValues(alpha: 0.08);
        borderColor = isRetro
            ? AppColors.cardBorder
            : AppColors.errorAlert.withValues(alpha: 0.18);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: isRetro ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (type == TagType.dnd) ...[
            Icon(
              Icons.shield_outlined,
              size: 10.5,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: 3.5),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTypography.tagChip.copyWith(
                color: textColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
