import 'package:hive/hive.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';

/// Central hub capturing all interactions strictly limited to [DailyTaskInstance] logic.
class DailyTaskInstanceRepository {
  final Box<DailyTaskInstance> _box = Hive.box<DailyTaskInstance>('dailyTaskInstances');

  /// Retrieves tasks exclusively mapped to a specific calendar date.
  List<DailyTaskInstance> getTasksForDate(DateTime date) {
    return _box.values.where((t) => _isSameDay(t.date, date)).toList();
  }

  /// Fetches all floating tasks currently pending irrespective of date for EOD check-in.
  List<DailyTaskInstance> getAllPendingFloating() {
    return _box.values
        .where((t) =>
            t.taskType == TaskType.floating && t.status == TaskStatus.pending)
        .toList();
  }

  /// Stores or updates an individual task instance.
  Future<void> save(DailyTaskInstance task) async {
    await _box.put(task.id, task);
  }

  /// Commits a batch generation of daily tasks.
  Future<void> saveAll(List<DailyTaskInstance> tasks) async {
    final Map<dynamic, DailyTaskInstance> entries = {
      for (var t in tasks) t.id: t
    };
    await _box.putAll(entries);
  }

  /// Destroys the task instance strictly locally.
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
