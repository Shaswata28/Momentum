import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';

class ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  final bool isPrimary;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    this.icon,
    required this.label,
    this.color,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color != null 
        ? color!.withValues(alpha: 0.15) 
        : (isPrimary ? AppColors.accentPrimary : AppColors.cardHoverActive);
        
    final fgColor = color != null 
        ? color! 
        : (isPrimary ? Colors.white : AppColors.textPrimary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
           color: bgColor,
           borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             if (icon != null) ...[
               Icon(icon, color: fgColor, size: 18),
               const SizedBox(width: 8),
             ],
             Text(label, style: AppTypography.buttonLabel.copyWith(color: fgColor)),
          ],
        ),
      ),
    );
  }
}
