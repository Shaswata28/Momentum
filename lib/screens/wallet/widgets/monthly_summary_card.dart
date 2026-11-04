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
    final totals = ref.watch(monthlyTotalsProvider);
    final runningBalance = ref.watch(runningBalanceProvider);
    final isSurplus = totals.netSavings >= 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Row: Section Label + Status Badge ────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 14,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('NET BALANCE', style: AppTypography.sectionLabel),
                ],
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSurplus ? AppColors.successDone : AppColors.errorAlert).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isSurplus ? AppColors.successDone : AppColors.errorAlert).withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 13,
                      color: isSurplus ? AppColors.successDone : AppColors.errorAlert,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSurplus ? 'Surplus' : 'Deficit',
                      style: AppTypography.tagChip.copyWith(
                        color: isSurplus ? AppColors.successDone : AppColors.errorAlert,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Balance Amount (Full-width & Formatted) ─────────────────
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '৳',
                  style: AppTypography.displayHeading.copyWith(
                    fontSize: 24,
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: runningBalance),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return Text(
                      NumberFormat('#,##0.00').format(val),
                      style: AppTypography.amountLarge,
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),

          // ── Income vs Expense Breakdown Row ─────────────────────────
          Row(
            children: [
              // Income
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.successDone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_downward_rounded, size: 17, color: AppColors.successDone),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income',
                            style: AppTypography.tagChip.copyWith(
                              color: AppColors.textPlaceholder,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: totals.totalIncome),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) {
                              return Text(
                                '+৳${NumberFormat('#,##0').format(val.toInt())}',
                                style: AppTypography.scoreStat.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.successDone,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.06),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),

              // Expense
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.errorAlert.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_upward_rounded, size: 17, color: AppColors.errorAlert),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense',
                            style: AppTypography.tagChip.copyWith(
                              color: AppColors.textPlaceholder,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: totals.totalExpense),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) {
                              return Text(
                                '-৳${NumberFormat('#,##0').format(val.toInt())}',
                                style: AppTypography.scoreStat.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.errorAlert,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
