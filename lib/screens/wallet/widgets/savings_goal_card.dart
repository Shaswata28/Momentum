import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../providers/wallet_providers.dart';

class SavingsGoalCard extends StatelessWidget {
  final double saved;
  final double goal;
  
  const SavingsGoalCard({super.key, required this.saved, required this.goal});

  @override
  Widget build(BuildContext context) {
    if (goal <= 0) return const SizedBox.shrink();

    final pct = (saved / goal).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
         color: AppColors.accentTagBackground,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Semester Goal', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: AppTypography.navLabel.copyWith(color: AppColors.accentPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
               value: pct,
               backgroundColor: const Color(0xFF1E1E2E),
               valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
               minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text('${currencyFormat.format(saved)} / ${currencyFormat.format(goal)} saved', style: AppTypography.scoreStat),
        ],
      ),
    );
  }
}
