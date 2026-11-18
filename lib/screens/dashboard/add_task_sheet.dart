import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
  TimeOfDay? _selectedTime;
  double _durationHours = 0.5;
  bool _saving = false;
  final String _taskId = const Uuid().v4();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDuration(double hours) {
    if (hours < 1.0) {
      return '${(hours * 60).round()} min';
    } else if (hours == 1.0) {
      return '1 hour';
    } else if (hours == hours.roundToDouble()) {
      return '${hours.toInt()} hours';
    } else {
      return '$hours hrs';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title.'),
        ),
      );
      return;
    }
    final duration = (_durationHours * 60).round().clamp(1, 1440);
    setState(() => _saving = true);
    try {
      await ref
          .read(todayTasksProvider.notifier)
          .addAdHocTask(title, _selectedTime, duration, id: _taskId);
      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish saving. Check Today before retrying; your inputs are kept.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
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

  Future<void> _pickCustomDuration() async {
    final ctrl = TextEditingController(text: _durationHours.toString());
    final res = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppColors.isRetro
              ? BorderRadius.zero
              : BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.cardBorder,
            width: AppColors.isRetro ? 2 : 1,
          ),
        ),
        title: Text(
          'Task Duration (hours)',
          style: AppTypography.titleLarge.copyWith(fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 0.5, 1.5, 3',
            hintStyle: TextStyle(color: AppColors.textPlaceholder),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null && v > 0 && v <= 24) {
                Navigator.pop(ctx, v);
              }
            },
            child: Text('Set', style: TextStyle(color: AppColors.accentPrimary)),
          ),
        ],
      ),
    );
    if (res != null && mounted) {
      setState(() => _durationHours = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final radius = isRetro ? BorderRadius.zero : BorderRadius.circular(12);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.cardBorder,
          width: isRetro ? 2.0 : 1.0,
        ),
        boxShadow: isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(0, -3),
                  blurRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: AppColors.isDark ? 0.35 : 0.12,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 20 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.cardBorder
                      : (AppColors.isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.15)),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header: Title & Close Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'New Task',
                  style: AppTypography.titleLarge.copyWith(
                    fontSize: isRetro ? 14 : 18,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textPlaceholder,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title Field
            Container(
              decoration: BoxDecoration(
                color: isRetro
                    ? AppColors.inputBackground
                    : AppColors.appBackground,
                borderRadius: radius,
                border: Border.all(
                  color: isRetro ? AppColors.cardBorder : AppColors.subtleBorder,
                  width: isRetro ? 2.0 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: _titleController,
                autofocus: true,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: isRetro ? 13 : 15,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: isRetro ? 12 : 14,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 12),

            // Options Row: Time Picker & Duration Selector side by side
            Row(
              children: [
                // Time Button
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: radius,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isRetro
                            ? AppColors.inputBackground
                            : AppColors.appBackground,
                        borderRadius: radius,
                        border: Border.all(
                          color: _selectedTime != null
                              ? AppColors.accentPrimary
                              : (isRetro
                                  ? AppColors.cardBorder
                                  : AppColors.subtleBorder),
                          width: isRetro ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
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
                              style: (_selectedTime != null
                                      ? AppTypography.cardTime
                                      : AppTypography.bodyText)
                                  .copyWith(
                                fontSize: isRetro ? 10.5 : 13,
                                color: _selectedTime != null
                                    ? AppColors.accentPrimary
                                    : AppColors.textPlaceholder,
                                fontWeight: _selectedTime != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedTime != null)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selectedTime = null),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: AppColors.textPlaceholder,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: AppColors.textPlaceholder,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Duration Selector Button
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: AppColors.cardBackground,
                    ),
                    child: PopupMenuButton<double>(
                      tooltip: 'Select duration',
                      initialValue: _durationHours,
                      onSelected: (val) {
                        if (val < 0) {
                          _pickCustomDuration();
                        } else {
                          HapticFeedback.selectionClick();
                          setState(() => _durationHours = val);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 0.25, child: Text('15 min')),
                        const PopupMenuItem(value: 0.5, child: Text('30 min')),
                        const PopupMenuItem(value: 0.75, child: Text('45 min')),
                        const PopupMenuItem(value: 1.0, child: Text('1 hour')),
                        const PopupMenuItem(value: 1.5, child: Text('1.5 hours')),
                        const PopupMenuItem(value: 2.0, child: Text('2 hours')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: -1.0, child: Text('Custom...')),
                      ],
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isRetro
                              ? AppColors.inputBackground
                              : AppColors.appBackground,
                          borderRadius: radius,
                          border: Border.all(
                            color: isRetro
                                ? AppColors.cardBorder
                                : AppColors.subtleBorder,
                            width: isRetro ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timelapse_rounded,
                              size: 15,
                              color: AppColors.textPlaceholder,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDuration(_durationHours),
                                style: AppTypography.bodyText.copyWith(
                                  fontSize: isRetro ? 10.5 : 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: AppColors.textPlaceholder,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Save Task Button
            ActionButton(
              label: _saving ? 'Saving...' : 'Save Task',
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
