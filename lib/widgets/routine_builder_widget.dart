import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../providers/routine_providers.dart';
import '../models/routine_task.dart';
import '../screens/routine/task_editor_sheet.dart';
import '../screens/routine/task_block.dart';

/// Embeddable version of the routine builder (no Scaffold/AppBar).
/// Can be used inside PageView steps (FTUE) or any scrollable container.
class RoutineBuilderWidget extends ConsumerWidget {
  const RoutineBuilderWidget({super.key});

  static const List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  void _openEditor(BuildContext context, {RoutineTask? task, int? initialDay}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskEditorSheet(existingTask: task, initialDay: initialDay),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(routineTasksProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(7, (index) {
          final dayIndex = index + 1; // 1 = Monday
          final dayTasks = tasks.where((t) => t.daysOfWeek.contains(dayIndex)).toList()
            ..sort((a, b) {
              if (a.scheduledTime != null && b.scheduledTime != null) {
                return (a.scheduledTime!.hour * 60 + a.scheduledTime!.minute)
                    .compareTo(b.scheduledTime!.hour * 60 + b.scheduledTime!.minute);
              }
              if (a.scheduledTime != null) return -1;
              if (b.scheduledTime != null) return 1;
              return 0;
            });

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    days[index],
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: Color(0xFF888898)),
                  ),
                ),
                ...dayTasks.map((t) => TaskBlock(
                  task: t,
                  onTap: () => _openEditor(context, task: t),
                )),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _openEditor(context, initialDay: dayIndex),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13131A),
                      border: Border.all(color: const Color(0xFF1A1A24)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text('+', style: TextStyle(color: AppColors.accentPrimary, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
