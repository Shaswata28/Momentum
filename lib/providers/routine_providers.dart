import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/routine_task.dart';
import '../../models/routine_period.dart';
import '../../repositories/routine_task_repository.dart';
import '../../repositories/routine_period_repository.dart';
import 'dashboard_providers.dart';

final routinePeriodRepoProvider = Provider((ref) => RoutinePeriodRepository());
final routineTaskRepoProvider = Provider((ref) => RoutineTaskRepository());

final activePeriodProvider = Provider<RoutinePeriod?>((ref) {
  final repo = ref.watch(routinePeriodRepoProvider);
  return repo.getActivePeriod();
});

final routineTasksProvider = StateNotifierProvider<RoutineTasksNotifier, List<RoutineTask>>((ref) {
  final repo = ref.watch(routineTaskRepoProvider);
  final activePeriod = ref.watch(activePeriodProvider);
  return RoutineTasksNotifier(repo, activePeriod?.id, ref);
});

class RoutineTasksNotifier extends StateNotifier<List<RoutineTask>> {
  final RoutineTaskRepository repo;
  final String? activePeriodId;
  final Ref ref;
  
  RoutineTasksNotifier(this.repo, this.activePeriodId, this.ref) : super([]) {
    loadTasks();
  }

  void loadTasks() {
    final periodIdToLoad = activePeriodId ?? 'default_period';
    state = repo.getAllForPeriod(periodIdToLoad);
  }

  Future<void> saveTask(RoutineTask task) async {
    await repo.save(task);
    loadTasks();
    ref.read(todayTasksProvider.notifier).loadTodayTasks();
  }

  Future<void> deleteTask(String id) async {
    await repo.delete(id);
    loadTasks();
    ref.read(todayTasksProvider.notifier).loadTodayTasks();
  }
}
