import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/routine_providers.dart';
import '../../models/routine_task.dart';
import 'task_editor_sheet.dart';
import 'task_block.dart';

class RoutineBuilderScreen extends ConsumerWidget {
  const RoutineBuilderScreen({super.key});

  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
    final todayIndex = DateTime.now().weekday; // 1=Mon

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF161619),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E1E26)),
                          ),
                          child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('Weekly Routine', style: AppTypography.displayHeading),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Period pill + task count
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161619),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF1E1E26)),
                        ),
                        child: Text(
                          activePeriod?.label ?? 'No active period',
                          style: AppTypography.bodyText.copyWith(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161619),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF1E1E26)),
                        ),
                        child: Text(
                          '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                          style: AppTypography.scoreStat.copyWith(
                            color: AppColors.accentPrimary, fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Day columns ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (index) {
                    final dayIndex = index + 1;
                    final isToday = dayIndex == todayIndex;
                    final dayTasks = tasks.where((t) => t.daysOfWeek.contains(dayIndex)).toList();
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
                      width: 138,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Day header
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.accentPrimary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isToday
                                  ? Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isToday) ...[
                                  Container(
                                    width: 6, height: 6,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ],
                                Text(
                                  _days[index],
                                  style: AppTypography.sectionLabel.copyWith(
                                    color: isToday ? AppColors.accentPrimary : AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${dayTasks.length}',
                                  style: AppTypography.sectionLabel.copyWith(
                                    color: isToday
                                        ? AppColors.accentPrimary.withValues(alpha: 0.6)
                                        : const Color(0xFF333340),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Task list
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  ...dayTasks.map((t) => TaskBlock(
                                    task: t,
                                    onTap: () => _openEditor(context, task: t),
                                  )),
                                  const SizedBox(height: 6),
                                  // Add button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _openEditor(context, initialDay: dayIndex);
                                    },
                                    child: Container(
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBackground,
                                        border: Border.all(color: const Color(0xFF1E1E26)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.add, color: AppColors.accentPrimary, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
