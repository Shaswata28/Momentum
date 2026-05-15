import 'package:flutter/material.dart';
import '../../models/routine_task.dart';
import '../../models/enums.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

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

    if (task.color != null) {
      final parsed = Color(int.parse(task.color!.replaceFirst('#', '0xFF')));
      bg = parsed.withValues(alpha: 0.12);
      border = parsed.withValues(alpha: 0.3);
      dot = parsed;
    } else if (task.taskType == TaskType.fixed) {
      bg = const Color(0xFF0D1520);
      border = const Color(0xFF1A2A40);
      dot = AppColors.fixedTask;
    } else {
      bg = const Color(0xFF12151A);
      border = const Color(0xFF1A2028);
      dot = AppColors.floatingTask;
    }

    final timeStr = task.taskType == TaskType.fixed
        ? _formatTime(task.scheduledTime)
        : 'flexible';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title row with dot
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
                ),
                Expanded(
                  child: Text(
                    task.title,
                    style: AppTypography.cardTitle.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Meta row: time + duration
            Row(
              children: [
                if (timeStr.isNotEmpty) ...[
                  Text(
                    timeStr,
                    style: AppTypography.cardTime.copyWith(fontSize: 10),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 3, height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _durationLabel(task.durationMinutes),
                  style: AppTypography.sectionLabel.copyWith(fontSize: 10),
                ),
              ],
            ),
            // DND badge
            if (task.enableDND) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warningTag.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DND',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.warningTag, fontSize: 8,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
