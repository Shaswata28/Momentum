import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/routine_providers.dart';
import '../../models/routine_task.dart';
import '../../constants/date_constants.dart';
import 'task_wizard_screen.dart';
import 'task_block.dart';

class RoutineBuilderScreen extends ConsumerWidget {
  const RoutineBuilderScreen({super.key});

  static const List<String> _days = AppDateConstants.shortDays;
  static const List<int> _dayIndices = AppDateConstants.weekDaysOrder;

  void _openEditor(BuildContext context, {RoutineTask? task, int? initialDay}) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskWizardScreen(existingTask: task, initialDay: initialDay),
      ),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Weekly Routine',
                          style: AppTypography.displayHeading.copyWith(fontSize: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Period pill + task count
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Text(
                          activePeriod?.label ?? 'General Routine',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentPrimary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                          style: AppTypography.scoreStat.copyWith(
                            color: AppColors.accentPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Day columns ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(7, (index) {
                    final dayIndex = _dayIndices[index];
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
                      width: 144,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Day header
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppColors.accentPrimary.withValues(alpha: 0.12)
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isToday
                                    ? AppColors.accentPrimary.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isToday) ...[
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ],
                                Text(
                                  _days[index],
                                  style: AppTypography.sectionLabel.copyWith(
                                    color: isToday ? AppColors.accentPrimary : AppColors.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? AppColors.accentPrimary.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${dayTasks.length}',
                                    style: AppTypography.scoreStat.copyWith(
                                      color: isToday
                                          ? AppColors.accentPrimary
                                          : AppColors.textPlaceholder,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Task list
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
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
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.06),
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.add_rounded,
                                        color: AppColors.accentPrimary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
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
