import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry? margin;
  final String tooltip;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.size = 40,
    this.margin,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

    return Semantics(
      button: true,
      label: tooltip,
      child: Container(
        margin: margin,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            if (onPressed != null) {
              onPressed!();
            } else {
              Navigator.maybePop(context);
            }
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.cardBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
