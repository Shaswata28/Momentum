import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';

class ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onTap;

  const ActionButton({
    super.key,
    this.icon,
    required this.label,
    this.color,
    this.isPrimary = false,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final enabled = onTap != null && !isLoading;
    final filled = isPrimary || (isRetro && color != null);
    final background = filled
        ? color ?? AppColors.accentPrimary
        : color?.withValues(alpha: 0.12) ?? AppColors.cardHoverActive;
    final foreground = filled
        ? (background.computeLuminance() > 0.179 ? Colors.black : Colors.white)
        : color ?? AppColors.textPrimary;
    final radius = isRetro ? BorderRadius.zero : BorderRadius.circular(12);

    return Semantics(
      button: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      label: isLoading ? '$label, in progress' : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || isLoading ? 1 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: isRetro && enabled
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(2, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: AppColors.cardBorder,
                width: isRetro ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      onTap!();
                    }
                  : null,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading) ...[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (icon != null) ...[
                        Icon(icon, color: foreground, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: AppTypography.buttonLabel.copyWith(
                              color: foreground,
                              fontSize: isRetro ? 10 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
