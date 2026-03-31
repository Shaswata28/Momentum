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

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    if (task.taskType == TaskType.fixed) {
      bg = const Color(0xFF0D1D35); // Accent tint
      border = const Color(0xFF1A3050);
    } else {
      bg = const Color(0xFF13171C); // Floating tint
      border = const Color(0xFF1A222C);
    }

    String timeStr;
    if (task.taskType == TaskType.fixed) {
      timeStr = _formatTime(task.scheduledTime);
    } else {
      timeStr = 'floating';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: task.color != null ? Color(int.parse(task.color!.replaceFirst('#', '0xFF'))).withOpacity(0.15) : bg,
          border: Border.all(color: task.color != null ? Color(int.parse(task.color!.replaceFirst('#', '0xFF'))).withOpacity(0.3) : border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(task.title, style: AppTypography.cardTitle.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(timeStr, style: AppTypography.cardTime.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
