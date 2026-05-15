import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../providers/wallet_providers.dart';

class BudgetBar extends StatelessWidget {
  final double spent;
  final double limit;
  
  const BudgetBar({super.key, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    if (limit <= 0) return const SizedBox.shrink();

    final pct = (spent / limit).clamp(0.0, 1.0);
    final over = spent > limit;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Budget', style: AppTypography.sectionLabel),
              Text('${currencyFormat.format(spent)} / ${currencyFormat.format(limit)}', style: AppTypography.navLabel.copyWith(color: over ? AppColors.errorAlert : AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
               value: pct,
               backgroundColor: const Color(0xFF1E1E2E),
               valueColor: AlwaysStoppedAnimation<Color>(over ? AppColors.errorAlert : AppColors.accentPrimary),
               minHeight: 6,
            ),
          )
        ],
      ),
    );
  }
}
