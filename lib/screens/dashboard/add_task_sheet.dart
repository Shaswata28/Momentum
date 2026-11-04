import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_providers.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';
import '../../widgets/action_button.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key});

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '0.5');
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.mediumImpact();
    final double parsedHr = double.tryParse(_durationController.text) ?? 0.5;
    final duration = (parsedHr * 60).round();
    ref.read(todayTasksProvider.notifier).addAdHocTask(title, _selectedTime, duration);
    Navigator.of(context).pop();
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accentPrimary,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_task_rounded,
                    color: AppColors.accentPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Task', style: AppTypography.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      'Add an ad-hoc task for today',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Title Field
            Text('TASK TITLE', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: _titleController,
                autofocus: true,
                style: AppTypography.cardTitle.copyWith(fontSize: 15),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 18),

            // Time and Duration Row
            Row(
              children: [
                // Scheduled Time Picker Button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TIME (OPTIONAL)', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.appBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTime != null
                                  ? AppColors.accentPrimary.withValues(alpha: 0.4)
                                  : AppColors.subtleBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: _selectedTime != null
                                    ? AppColors.accentPrimary
                                    : AppColors.textPlaceholder,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedTime != null
                                      ? _selectedTime!.format(context)
                                      : 'Anytime',
                                  style: _selectedTime != null
                                      ? AppTypography.cardTime.copyWith(fontSize: 13)
                                      : AppTypography.bodyText.copyWith(
                                          color: AppColors.textPlaceholder,
                                          fontSize: 13,
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedTime != null)
                                GestureDetector(
                                  onTap: () => setState(() => _selectedTime = null),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Duration Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DURATION (HOURS)', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.appBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.timelapse_rounded,
                              size: 16,
                              color: AppColors.textPlaceholder,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _durationController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: AppTypography.scoreStat.copyWith(fontSize: 13),
                                cursorColor: AppColors.accentPrimary,
                                decoration: InputDecoration(
                                  hintText: '0.5',
                                  hintStyle: AppTypography.scoreStat.copyWith(
                                    color: AppColors.textPlaceholder,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            Text(
                              'hr',
                              style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Save Action Button
            ActionButton(
              label: 'Save Task',
              isPrimary: true,
              icon: Icons.check_rounded,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
