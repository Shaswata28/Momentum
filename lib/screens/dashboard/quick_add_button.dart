import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'add_task_sheet.dart';

class QuickAddButton extends StatefulWidget {
  const QuickAddButton({super.key});

  @override
  State<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<QuickAddButton> {
  bool _isPressed = false;

  void _onTap(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddTaskSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

    return GestureDetector(
      onTap: () => _onTap(context),
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(14),
            border: Border.all(
              color: _isPressed
                  ? AppColors.accentPrimary
                  : AppColors.cardBorder,
              width: isRetro ? 2.0 : 1.0,
            ),
            boxShadow: isRetro && !_isPressed
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: isRetro ? 0.2 : 0.12),
                  borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(7),
                  border: isRetro ? Border.all(color: AppColors.cardBorder, width: 1.5) : null,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add a task for today...',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
