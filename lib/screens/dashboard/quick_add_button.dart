import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'add_task_sheet.dart';
import 'package:flutter/services.dart';

class QuickAddButton extends StatefulWidget {
  const QuickAddButton({super.key});
  
  @override
  State<QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<QuickAddButton> {
  bool _isHovered = false;

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
    return GestureDetector(
      onTap: () => _onTap(context),
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 24), // Margin added for scroll clearance
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(14),
          // We use solid borderline to simulate dashed specs safely inside Flutter's native box tree
          border: Border.all(color: _isHovered ? AppColors.accentPrimary : const Color(0xFF252535)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF252545)),
              ),
              child: const Text('+', style: TextStyle(color: AppColors.accentPrimary, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Text('Add a task for today...', style: AppTypography.bodyText.copyWith(color: const Color(0xFF333345), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
