import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import '../../models/eod_log.dart';
import '../../models/wallet_settings.dart';
import '../../repositories/eod_log_repository.dart';
import '../../providers/wallet_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/health_score_ring.dart';
import '../../widgets/budget_discipline_indicator.dart';
import '../log/eod_log_screen.dart';

final eodRepoProvider = Provider((ref) => EODLogRepository());

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  // 0 = Routine, 1 = Wallet
  int _currentView = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(eodRepoProvider);

    return FutureBuilder<List<EODLog>>(
      future: Future.value(repo.getAllLogs()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.appBackground,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final logs = snapshot.data!;

        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final weeklyLogs = logs
            .where((l) => l.date.isAfter(startOfWeek.subtract(const Duration(days: 1))))
            .toList();

        double weeklyScore = 0.0;
        if (weeklyLogs.isNotEmpty) {
          weeklyScore = weeklyLogs.map((e) => e.healthScore).reduce((a, b) => a + b) / weeklyLogs.length;
        }

        String grade = 'F';
        if (weeklyScore >= 90) {
          grade = 'A';
        } else if (weeklyScore >= 80) {
          grade = 'B';
        } else if (weeklyScore >= 70) {
          grade = 'C';
        } else if (weeklyScore >= 60) {
          grade = 'D';
        }

        final hasTodayLog = logs.any((l) =>
            l.date.year == now.year &&
            l.date.month == now.month &&
            l.date.day == now.day);
        final showCloseDay = !hasTodayLog && now.hour >= 21;

        return Scaffold(
          backgroundColor: AppColors.appBackground,
          appBar: AppBar(
            backgroundColor: AppColors.appBackground,
            title: Text('Insights', style: AppTypography.displayHeading),
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SegmentedToggle(
                  current: _currentView,
                  onChanged: (v) => setState(() => _currentView = v),
                ),
              ),
            ),
          ),
          floatingActionButton: (_currentView == 0 && showCloseDay)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EODLogScreen(),
                        fullscreenDialog: true,
                      ),
                    ).then((_) => setState(() {}));
                  },
                  backgroundColor: AppColors.accentPrimary,
                  icon: const Icon(Icons.nightlight_round, color: Colors.white),
                  label: Text('Close Day',
                      style: AppTypography.buttonLabel.copyWith(color: Colors.white)),
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: _currentView == 0
                ? _RoutineView(
                    key: const ValueKey('routine'),
                    logs: logs,
                    weeklyLogs: weeklyLogs,
                    weeklyScore: weeklyScore,
                    grade: grade,
                  )
                : const _WalletView(key: ValueKey('wallet')),
          ),
        );
      },
    );
  }
}

// ─── Segmented Toggle ─────────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;
  static const _labels = ['Routine', 'Wallet'];

  const _SegmentedToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = current == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: active ? AppColors.accentPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: AppTypography.buttonLabel.copyWith(
                    color: active ? Colors.white : AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Routine View (existing content) ─────────────────────────────────────────

class _RoutineView extends StatelessWidget {
  final List<EODLog> logs;
  final List<EODLog> weeklyLogs;
  final double weeklyScore;
  final String grade;

  const _RoutineView({
    super.key,
    required this.logs,
    required this.weeklyLogs,
    required this.weeklyScore,
    required this.grade,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHealthScoreRingCard(),
          const SizedBox(height: 24),
          _buildEnergyChart(),
          const SizedBox(height: 24),
          _buildConsistencyMap(),
          const SizedBox(height: 80), // space for FAB
        ],
      ),
    );
  }

  Widget _buildHealthScoreRingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          HealthScoreRing(score: weeklyScore, grade: grade),
          const SizedBox(height: 12),
          Text('${weeklyLogs.length} / 7 days logged',
              style: AppTypography.sectionLabel),
        ],
      ),
    );
  }

  Widget _buildEnergyChart() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < 7; i++) {
      final d = startOfWeek.add(Duration(days: i));
      final log = weeklyLogs
          .where((l) =>
              l.date.year == d.year &&
              l.date.month == d.month &&
              l.date.day == d.day)
          .firstOrNull;
      final isToday =
          d.year == now.year && d.month == now.month && d.day == now.day;
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: log?.energyLevel.toDouble() ?? 0.0,
            color: isToday ? AppColors.accentPrimary : AppColors.accentTagBackground,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      ));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENERGY THIS WEEK', style: AppTypography.sectionLabel),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 10,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(days[value.toInt()],
                            style: AppTypography.sectionLabel),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyMap() {
    final days = List.generate(
        35, (i) => DateTime.now().subtract(Duration(days: 34 - i)));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CONSISTENCY MAP • LAST 35 DAYS',
                  style: AppTypography.sectionLabel),
              Text('${logs.length} LOGS', style: AppTypography.scoreStat),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              final logEntry = logs
                  .where((l) =>
                      l.date.year == day.year &&
                      l.date.month == day.month &&
                      l.date.day == day.day)
                  .firstOrNull;
              Color blockColor = AppColors.elevatedSurface;
              if (logEntry != null) {
                if (logEntry.healthScore >= 75) {
                  blockColor = AppColors.accentPrimary;
                } else if (logEntry.healthScore >= 50) {
                  blockColor = AppColors.accentPrimary.withValues(alpha: 0.6);
                } else {
                  blockColor = AppColors.accentPrimary.withValues(alpha: 0.25);
                }
              }
              return Tooltip(
                message:
                    '${day.month}/${day.day}: ${logEntry != null ? logEntry.healthScore.toStringAsFixed(1) : "No log"}',
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Wallet View (new) ────────────────────────────────────────────────────────

class _WalletView extends ConsumerWidget {
  const _WalletView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(currentMonthSummaryProvider);
    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings = settingsBox.isNotEmpty ? settingsBox.getAt(0) : null;

    final income = summary?.totalIncome ?? 0.0;
    final spent = summary?.totalExpense ?? 0.0;
    final opening = summary?.openingBalance ?? 0.0;
    final saved = (income - spent + opening).clamp(0.0, double.infinity);
    final semGoal = settings?.semesterGoal ?? 0.0;

    final repo = ref.watch(eodRepoProvider);
    final now = DateTime.now();
    final monthLogs = repo.getLogsForMonth(now.year, now.month);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildIncomeSpendCard(income, spent),
          const SizedBox(height: 20),
          _buildSavingsCard(saved, semGoal),
          const SizedBox(height: 20),
          BudgetDisciplineIndicator(monthLogs: monthLogs),
        ],
      ),
    );
  }

  // Card 1: Income vs Spend bar chart
  Widget _buildIncomeSpendCard(double income, double spent) {
    final maxY = (income > spent ? income : spent) * 1.2;
    final safeMax = maxY <= 0 ? 100.0 : maxY;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INCOME VS SPEND', style: AppTypography.sectionLabel),
          const SizedBox(height: 6),
          Text('This month', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: safeMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A24),
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      '৳${rod.toY.toStringAsFixed(0)}',
                      AppTypography.scoreStat.copyWith(color: AppColors.textPrimary),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Income', 'Spent'];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[idx],
                              style: AppTypography.sectionLabel
                                  .copyWith(color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: safeMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0xFF1A1A24),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: income,
                      color: AppColors.successDone,
                      width: 40,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: spent,
                      color: AppColors.warningTag,
                      width: 40,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Totals row
          Row(
            children: [
              _StatPill('Income', income, AppColors.successDone),
              const SizedBox(width: 12),
              _StatPill('Spent', spent, AppColors.warningTag),
              const SizedBox(width: 12),
              _StatPill('Net', income - spent,
                  income >= spent ? AppColors.successDone : AppColors.errorAlert),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2: Savings Goal
  Widget _buildSavingsCard(double saved, double semGoal) {
    if (semGoal <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF121217),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A1A24)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Set a semester savings goal in Profile to track it here.',
                style: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    final pct = (saved / semGoal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SEMESTER SAVINGS GOAL', style: AppTypography.sectionLabel),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: AppTypography.scoreStat
                      .copyWith(color: AppColors.accentPrimary, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFF1E1E2E),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(currencyFormat.format(saved),
                  style: AppTypography.scoreStat
                      .copyWith(color: AppColors.textPrimary, fontSize: 15)),
              Text('of ${currencyFormat.format(semGoal)}',
                  style: AppTypography.bodyText
                      .copyWith(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTypography.sectionLabel
                    .copyWith(color: color, fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              '৳${value.abs().toStringAsFixed(0)}',
              style: AppTypography.scoreStat.copyWith(color: color, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
