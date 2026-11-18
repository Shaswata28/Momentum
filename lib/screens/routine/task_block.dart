import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/routine_task.dart';
import '../../models/enums.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';

class TaskBlock extends StatelessWidget {
  final RoutineTask task;
  final VoidCallback onTap;

  const TaskBlock({super.key, required this.task, required this.onTap});

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt).toLowerCase();
  }

  String _durationLabel(int min) {
    if (min < 60) return '${min}m';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    // Resolve colors
    Color bg;
    Color border;
    Color dot;

    if (task.color != null && task.color!.isNotEmpty) {
      try {
        final parsed = Color(int.parse(task.color!.replaceFirst('#', '0xFF')));
        bg = parsed.withValues(alpha: 0.10);
        border = parsed.withValues(alpha: 0.26);
        dot = parsed;
      } catch (_) {
        bg = AppColors.fixedTask.withValues(alpha: 0.10);
        border = AppColors.fixedTask.withValues(alpha: 0.25);
        dot = AppColors.fixedTask;
      }
    } else if (task.taskType == TaskType.fixed) {
      bg = AppColors.fixedTask.withValues(alpha: 0.10);
      border = AppColors.fixedTask.withValues(alpha: 0.25);
      dot = AppColors.fixedTask;
    } else if (task.taskType == TaskType.floating) {
      bg = AppColors.floatingTask.withValues(alpha: 0.10);
      border = AppColors.floatingTask.withValues(alpha: 0.25);
      dot = AppColors.floatingTask;
    } else {
      bg = AppColors.adHocTask.withValues(alpha: 0.10);
      border = AppColors.adHocTask.withValues(alpha: 0.25);
      dot = AppColors.adHocTask;
    }

    final timeStr = task.taskType == TaskType.fixed
        ? _formatTime(task.scheduledTime)
        : 'flexible';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: 'Edit task',
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppColors.isRetro ? AppColors.inkColor : border,
              width: AppColors.isRetro ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppColors.isRetro ? 0 : 12),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppColors.isRetro ? 0 : 12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row with dot
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dot,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          task.title,
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Meta row: time + duration
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (timeStr.isNotEmpty) ...[
                        Text(
                          timeStr,
                          style: AppTypography.cardTime.copyWith(
                            fontSize: 10,
                            color: dot,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ],
                      Text(
                        _durationLabel(task.durationMinutes),
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // DND badge
                  if (task.enableDND) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningTag.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppColors.isRetro ? 0 : 4,
                        ),
                        border: Border.all(
                          color: AppColors.warningTag.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'DND',
                        style: AppTypography.sectionLabel.copyWith(
                          color: AppColors.warningTag,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
