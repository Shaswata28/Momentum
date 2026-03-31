import '../models/daily_task_instance.dart';
import '../models/enums.dart';

class RoutineHealthScoreService {

  Map<String, dynamic> calculateDailyScore(List<DailyTaskInstance> tasks) {
    final scorable = tasks.where((t) => !t.isBufferBlock).toList();
    if (scorable.isEmpty) return {'score': 0.0, 'grade': 'F', 'rescheduled': 0};

    final fixed    = scorable.where((t) => t.taskType == TaskType.fixed).toList();
    final floating = scorable.where((t) => t.taskType == TaskType.floating).toList();
    final adhoc    = scorable.where((t) => t.taskType == TaskType.adhoc).toList();

    final fixedDone    = fixed.where((t) => t.status == TaskStatus.done).length;
    final floatingDone = floating.where((t) => t.status == TaskStatus.done).length;
    final adhocDone    = adhoc.where((t) => t.status == TaskStatus.done).length;

    // Rescheduled tasks count as partial credit (50%) — they weren't skipped
    final fixedRescheduled    = fixed.where((t) => t.status == TaskStatus.rescheduled).length;
    final floatingRescheduled = floating.where((t) => t.status == TaskStatus.rescheduled).length;
    final adhocRescheduled    = adhoc.where((t) => t.status == TaskStatus.rescheduled).length;
    final totalRescheduled    = fixedRescheduled + floatingRescheduled + adhocRescheduled;

    double _ratio(int done, int rescheduled, int total) {
      if (total == 0) return 1.0;
      return (done + rescheduled * 0.5) / total;
    }

    final fixedScore    = _ratio(fixedDone, fixedRescheduled, fixed.length);
    final floatingScore = _ratio(floatingDone, floatingRescheduled, floating.length);
    final adhocScore    = _ratio(adhocDone, adhocRescheduled, adhoc.length);

    // Weights: fixed 55%, floating 30%, adhoc 15%
    // If a category is empty its weight redistributes proportionally
    double totalWeight = 0;
    double weightedScore = 0;
    if (fixed.isNotEmpty)    { weightedScore += fixedScore * 55;    totalWeight += 55; }
    if (floating.isNotEmpty) { weightedScore += floatingScore * 30; totalWeight += 30; }
    if (adhoc.isNotEmpty)    { weightedScore += adhocScore * 15;    totalWeight += 15; }

    double finalScore = totalWeight > 0 ? (weightedScore / totalWeight) * 100 : 0.0;

    // Buffer overflow penalty (unchanged)
    double bufferPenalty = 0.0;
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.status == TaskStatus.done &&
          task.completedAt != null &&
          task.scheduledTime != null) {
        final taskStart = DateTime(
          task.completedAt!.year, task.completedAt!.month, task.completedAt!.day,
          task.scheduledTime!.hour, task.scheduledTime!.minute,
        );
        final expectedEnd = taskStart.add(Duration(minutes: task.durationMinutes));
        if (task.completedAt!.isAfter(expectedEnd)) {
          final overflowMin = task.completedAt!.difference(expectedEnd).inMinutes;
          if (i + 1 < tasks.length && tasks[i + 1].isBufferBlock) {
            bufferPenalty += (overflowMin / tasks[i + 1].durationMinutes) * 10.0;
          } else if (overflowMin > 0) {
            bufferPenalty += 5.0;
          }
        }
      }
    }

    finalScore = (finalScore - bufferPenalty).clamp(0.0, 100.0);

    return {
      'score': finalScore,
      'grade': getGradeFromScore(finalScore),
      'rescheduled': totalRescheduled,
    };
  }

  String getGradeFromScore(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
