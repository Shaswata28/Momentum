import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../providers/wallet_providers.dart';

class DailySpendingChart extends ConsumerWidget {
  const DailySpendingChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySpending = ref.watch(dailySpendingProvider);
    final selectedDate = DateTime.parse(
      '${ref.watch(currentMonthIdProvider)}-01',
    );
    final daysInMonth = DateUtils.getDaysInMonth(
      selectedDate.year,
      selectedDate.month,
    );

    if (dailySpending.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: AppColors.isRetro
              ? BorderRadius.zero
              : BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 36,
                color: AppColors.textPlaceholder,
              ),
              const SizedBox(height: 10),
              Text(
                'No spending in ${DateFormat.yMMMM().format(selectedDate)}',
                textAlign: TextAlign.center,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add an expense in Wallet to see daily trends.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyText.copyWith(
                  fontSize: 12,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ],
          ),
        ),
      );
    }

    double maxSpend = 0;
    for (final val in dailySpending.values) {
      if (val > maxSpend) maxSpend = val;
    }
    if (maxSpend == 0) maxSpend = 100;

    final isRetro = AppColors.isRetro;

    final barGroups = <BarChartGroupData>[];
    for (int day = 1; day <= daysInMonth; day++) {
      final amt = dailySpending[day] ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: day,
          barRods: [
            BarChartRodData(
              toY: amt,
              color: amt > 0 ? AppColors.accentPrimary : Colors.transparent,
              width: daysInMonth > 28 ? 5.5 : 6.5,
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(3),
              borderSide: isRetro && amt > 0
                  ? BorderSide(color: AppColors.cardBorder, width: 1.5)
                  : BorderSide.none,
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxSpend * 1.1,
                color: isRetro
                    ? AppColors.cardHoverActive.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardBorder,
          width: isRetro ? 2.0 : 1.0,
        ),
        boxShadow: isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'SPENDING: ${DateFormat.yMMMM().format(selectedDate)}',
                style: AppTypography.sectionLabel.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.0,
                  color: AppColors.textPlaceholder,
                ),
              ),
              Text(
                'Peak: ৳${maxSpend.toStringAsFixed(0)}',
                style: AppTypography.scoreStat.copyWith(
                  color: AppColors.textPlaceholder,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Total: ${currencyFormat.format(dailySpending.values.fold<double>(0, (sum, value) => sum + value))}. Peak day: ${currencyFormat.format(maxSpend)}.',
            style: AppTypography.bodyText,
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxSpend * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.cardHoverActive,
                    tooltipBorder: isRetro
                        ? BorderSide(color: AppColors.cardBorder, width: 1.5)
                        : BorderSide.none,
                    tooltipBorderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'Day ${group.x}\n',
                        AppTypography.tagChip.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: '৳${rod.toY.toStringAsFixed(0)}',
                            style: AppTypography.scoreStat.copyWith(
                              color: AppColors.accentPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt();
                        if (day == 1 ||
                            day == 7 ||
                            day == 14 ||
                            day == 21 ||
                            day == 28 ||
                            day == daysInMonth) {
                          return Text(
                            '$day',
                            style: AppTypography.tagChip.copyWith(
                              fontSize: 9.5,
                              color: AppColors.textPlaceholder,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: isRetro,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.dividerBorderHover,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(
                  show: isRetro,
                  border: Border(
                    bottom: BorderSide(color: AppColors.cardBorder, width: 1.5),
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
