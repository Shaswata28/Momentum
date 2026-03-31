import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../models/simple_goal.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class AddFocusScreen extends StatefulWidget {
  const AddFocusScreen({super.key});

  @override
  State<AddFocusScreen> createState() => _AddFocusScreenState();
}

class _AddFocusScreenState extends State<AddFocusScreen> {
  final _controller = TextEditingController();
  bool _isHabit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.mediumImpact();

    final goal = SimpleGoal(
      id: const Uuid().v4(),
      title: title,
      isHabit: _isHabit,
      createdAt: DateTime.now(),
    );

    await Hive.box<SimpleGoal>('simple_goals').add(goal);
    await NotificationService().scheduleFocusReminder(goal.id, goal.title, goal.isHabit);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Monthly Focus', style: AppTypography.displayHeading),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: AppTypography.bodyText.copyWith(color: const Color(0xFFD8D8E8)),
              cursorColor: AppColors.accentPrimary,
              decoration: InputDecoration(
                hintText: 'What is your focus?',
                hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textPlaceholder),
                filled: true,
                fillColor: AppColors.elevatedSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.accentPrimary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _TypeToggle(
              isHabit: _isHabit,
              onChanged: (v) => setState(() => _isHabit = v),
            ),
            const Spacer(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Save Focus', style: AppTypography.buttonLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final bool isHabit;
  final ValueChanged<bool> onChanged;

  const _TypeToggle({required this.isHabit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Segment(label: 'Goal', selected: !isHabit, onTap: () => onChanged(false)),
          _Segment(label: 'Habit', selected: isHabit, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentPrimary.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: selected ? Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.5)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodyText.copyWith(
              fontSize: 13,
              color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
