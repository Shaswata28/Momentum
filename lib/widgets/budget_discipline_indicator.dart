import 'package:flutter/material.dart';
import '../models/eod_log.dart';
import '../theme/app_colors.dart';

/// Displays the user's budget adherence rate for the current month,
/// derived from EOD logs that have a non-null [stuckToBudget] value.
class BudgetDisciplineIndicator extends StatelessWidget {
  final List<EODLog> monthLogs;

  const BudgetDisciplineIndicator({super.key, required this.monthLogs});

  @override
  Widget build(BuildContext context) {
    final answered = monthLogs.where((l) => l.stuckToBudget != null).toList();
    final answeredCount = answered.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Budget Discipline',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          if (answeredCount == 0)
            const Text(
              'Answer the budget check-in during EOD to track discipline here.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            )
          else
            _RateDisplay(answered: answered, answeredCount: answeredCount),
        ],
      ),
    );
  }
}

class _RateDisplay extends StatelessWidget {
  final List<EODLog> answered;
  final int answeredCount;

  const _RateDisplay({
    required this.answered,
    required this.answeredCount,
  });

  @override
  Widget build(BuildContext context) {
    final stuckCount = answered.where((l) => l.stuckToBudget == true).length;
    final rate = stuckCount / answeredCount;
    final color =
        rate >= 0.70 ? AppColors.successDone : AppColors.warningTag;
    final label =
        '$stuckCount / $answeredCount days — ${(rate * 100).toStringAsFixed(0)}%';

    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
