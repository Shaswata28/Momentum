import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/routine_providers.dart';
import '../../models/routine_task.dart';
import 'task_editor_sheet.dart';
import 'task_block.dart';

class RoutineBuilderScreen extends ConsumerWidget {
  const RoutineBuilderScreen({super.key});

  final List<String> days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
    final activePeriod = ref.watch(activePeriodProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF0F0F5)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Weekly Routine', style: AppTypography.displayHeading),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161619),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E1E26)),
                    ),
                    child: Text(
                      activePeriod?.label ?? 'No active period', 
                      style: AppTypography.bodyText.copyWith(fontSize: 11)
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Edit period', style: AppTypography.bodyText.copyWith(fontSize: 11, color: AppColors.accentPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (index) {
                    final dayIndex = index + 1; // 1 = Monday
                    final dayTasks = tasks.where((t) => t.daysOfWeek.contains(dayIndex)).toList();
                    // Sort structurally by scheduledTime naturally matching the spec flow
                    dayTasks.sort((a, b) {
                      if (a.scheduledTime != null && b.scheduledTime != null) {
                        return (a.scheduledTime!.hour * 60 + a.scheduledTime!.minute)
                            .compareTo(b.scheduledTime!.hour * 60 + b.scheduledTime!.minute);
                      }
                      if (a.scheduledTime != null && b.scheduledTime == null) return -1;
                      if (a.scheduledTime == null && b.scheduledTime != null) return 1;
                      return 0;
                    });

                    return Container(
                      width: 130, // Fixed width column mirroring spec layout
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(days[index], style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: Color(0xFF888898))),
                          ),
                          ...dayTasks.map((t) => TaskBlock(
                            task: t, 
                            onTap: () => _openEditor(context, task: t),
                          )),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _openEditor(context, initialDay: dayIndex),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
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
              ),
            )
          ],
        ),
      ),
    );
  }
}
