import 'package:hive/hive.dart';
import '../models/routine_task.dart';

/// Repository resolving operations related to [RoutineTask] storage.
class RoutineTaskRepository {
  final Box<RoutineTask> _box = Hive.box<RoutineTask>('routineTasks');

  /// Fetches all active tasks belonging to a specific routine period.
  List<RoutineTask> getAllForPeriod(String periodId) {
    return _box.values
        .where((t) => t.routinePeriodId == periodId && t.isActive)
        .toList();
  }

  /// Fetches tasks that should execute on a specific day of the week.
  List<RoutineTask> getTasksForDay(String periodId, int dayOfWeek) {
    return _box.values
        .where((t) =>
            t.routinePeriodId == periodId &&
            t.isActive &&
            t.daysOfWeek.contains(dayOfWeek))
        .toList();
  }

  /// Creates or updates a RoutineTask locally.
  Future<void> save(RoutineTask task) async {
    await _box.put(task.id, task);
  }

  /// Permanently deletes a RoutineTask. Note: Soft deletion (`isActive = false`) is commonly preferred.
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
