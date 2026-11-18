import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../providers/wallet_providers.dart';

class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(selectedMonthlyTotalsProvider);
    final balance = ref.watch(selectedRunningBalanceProvider);
    final opening =
        ref.watch(selectedMonthSummaryProvider)?.openingBalance ?? 0;
    final month = ref.watch(selectedMonthDateProvider);
    final isRetro = AppColors.isRetro;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: isRetro ? 2 : 1),
        boxShadow: isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(3, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat.yMMMM().format(month),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 12),
          Text('Cash balance', style: AppTypography.cardTitle),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(balance),
            style: AppTypography.amountLarge.copyWith(
              color: balance < 0 ? AppColors.errorAlert : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Opening balance: ${currencyFormat.format(opening)}',
            style: AppTypography.bodyText,
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.cardBorder),
          const SizedBox(height: 8),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _stat('Money in', totals.totalIncome, AppColors.successDone),
              _stat('Money out', totals.totalExpense, AppColors.errorAlert),
              _stat(
                totals.netSavings < 0
                    ? 'Net flow (deficit)'
                    : 'Net flow (surplus)',
                totals.netSavings,
                totals.netSavings < 0
                    ? AppColors.errorAlert
                    : AppColors.successDone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double amount, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
      ),
      const SizedBox(height: 4),
      Text(
        currencyFormat.format(amount),
        style: AppTypography.scoreStat.copyWith(color: color),
      ),
    ],
  );
}
