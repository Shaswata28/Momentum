import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/eod_log.dart';
import '../../models/transaction.dart';
import '../../models/wallet_settings.dart';
import '../../constants/date_constants.dart';
import '../../repositories/eod_log_repository.dart';
import '../../providers/wallet_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/health_score_ring.dart';
import '../../widgets/daily_spending_chart.dart';
import '../log/eod_log_screen.dart';

final eodRepoProvider = Provider((ref) => EODLogRepository());

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  // 0 = Routine & Focus, 1 = Wallet & Finance
  int _currentView = 0;

  int _calculateCurrentStreak(List<EODLog> logs) {
    if (logs.isEmpty) return 0;
    final sortedDates = logs
        .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (!sortedDates.contains(today) && !sortedDates.contains(yesterday)) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = sortedDates.contains(today) ? today : yesterday;

    while (sortedDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _calculateBestStreak(List<EODLog> logs) {
    if (logs.isEmpty) return 0;
    final sortedDates = logs
        .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));

    int best = 0;
    int current = 0;
    DateTime? prev;

    for (final d in sortedDates) {
      if (prev == null || d.difference(prev).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > best) best = current;
      prev = d;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(eodRepoProvider);

    return FutureBuilder<List<EODLog>>(
      future: Future.value(repo.getAllLogs()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.appBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            ),
          );
        }
        final logs = snapshot.data!;

        final now = DateTime.now();
        final startOfWeek = AppDateConstants.startOfWeek(now);
        final weeklyLogs = logs
            .where((l) => !l.date.isBefore(startOfWeek))
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

        final currentStreak = _calculateCurrentStreak(logs);
        final bestStreak = _calculateBestStreak(logs);

        final hasTodayLog = logs.any((l) =>
            l.date.year == now.year &&
            l.date.month == now.month &&
            l.date.day == now.day);
        final showCloseDay = !hasTodayLog && now.hour >= 21;

        return Scaffold(
          backgroundColor: AppColors.appBackground,
          appBar: _InsightsAppBar(
            currentView: _currentView,
            onViewChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _currentView = v);
            },
          ),
          floatingActionButton: (_currentView == 0 && showCloseDay)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EODLogScreen(),
                        fullscreenDialog: true,
                      ),
                    ).then((_) => setState(() {}));
                  },
                  backgroundColor: AppColors.accentPrimary,
                  elevation: 6,
                  icon: const Icon(Icons.nightlight_round, color: Colors.white, size: 20),
                  label: Text(
                    'Close Day',
                    style: AppTypography.buttonLabel.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _currentView == 0
                ? _RoutineView(
                    key: const ValueKey('routine_view'),
                    logs: logs,
                    weeklyLogs: weeklyLogs,
                    weeklyScore: weeklyScore,
                    grade: grade,
                    currentStreak: currentStreak,
                    bestStreak: bestStreak,
                  )
                : const _WalletView(key: ValueKey('wallet_view')),
          ),
        );
      },
    );
  }
}

// ─── Staggered Card Entry Wrapper ─────────────────────────────────────────────

class _StaggeredCard extends StatelessWidget {
  final Widget child;
  final int index;

  const _StaggeredCard({
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 360 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1.0 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

// ─── Smooth Animated Number Counter ──────────────────────────────────────────

class _AnimatedNumberText extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String prefix;

  const _AnimatedNumberText({
    required this.value,
    required this.style,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, _) {
        final formattedNumber = NumberFormat('#,##0').format(animatedVal.toInt());
        return Text('$prefix$formattedNumber', style: style);
      },
    );
  }
}

// ─── Pinned Header with Insights Title & Segmented Toggle ───────────────────

class _InsightsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentView;
  final ValueChanged<int> onViewChanged;

  const _InsightsAppBar({
    required this.currentView,
    required this.onViewChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(140);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.appBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Insights',
                style: AppTypography.displayHeading.copyWith(
                  fontSize: 26,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Performance trends & financial health',
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textPlaceholder,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),
              _AnimatedSegmentedToggle(
                current: currentView,
                onChanged: onViewChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Apple-Style Sliding Segmented Pill Switcher ──────────────────────────────

class _AnimatedSegmentedToggle extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _AnimatedSegmentedToggle({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        children: [
          // Animated Sliding Thumb
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: current == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentPrimary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Clickable Tab Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(0),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: current == 0 ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 7),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: AppTypography.buttonLabel.copyWith(
                              color: current == 0 ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: current == 0 ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                            child: const Text('Routine & Focus'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(1),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 16,
                            color: current == 1 ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 7),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: AppTypography.buttonLabel.copyWith(
                              color: current == 1 ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: current == 1 ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                            child: const Text('Wallet & Finance'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Routine & Focus View ─────────────────────────────────────────────────────

class _RoutineView extends StatefulWidget {
  final List<EODLog> logs;
  final List<EODLog> weeklyLogs;
  final double weeklyScore;
  final String grade;
  final int currentStreak;
  final int bestStreak;

  const _RoutineView({
    super.key,
    required this.logs,
    required this.weeklyLogs,
    required this.weeklyScore,
    required this.grade,
    required this.currentStreak,
    required this.bestStreak,
  });

  @override
  State<_RoutineView> createState() => _RoutineViewState();
}

class _RoutineViewState extends State<_RoutineView> {
  DateTime? _selectedHeatmapDay;
  EODLog? _selectedHeatmapLog;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 0. Animated Flame Streak Hero Banner ─────────────────────
          _StaggeredCard(
            index: 0,
            child: _buildStreakHero(),
          ),
          const SizedBox(height: 16),

          // ── 1. Weekly Performance & Health Score Ring ────────────────
          _StaggeredCard(
            index: 1,
            child: _buildHealthScoreCard(),
          ),
          const SizedBox(height: 16),

          // ── 2. Energy Trends Bar Chart ───────────────────────────────
          _StaggeredCard(
            index: 2,
            child: _buildEnergyChartCard(),
          ),
          const SizedBox(height: 16),

          // ── 3. Interactive 35-Day Consistency Heatmap ────────────────
          _StaggeredCard(
            index: 3,
            child: _buildConsistencyMapCard(),
          ),
        ],
      ),
    );
  }

  // ── Hero Streak Banner (Pixel-Perfect Alignment & No Overflows) ─────────────
  Widget _buildStreakHero() {
    final hasStreak = widget.currentStreak > 0;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Row: Section Label + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: AppColors.adHocTask,
                  ),
                  const SizedBox(width: 6),
                  Text('STREAK & MOMENTUM', style: AppTypography.sectionLabel),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasStreak
                      ? AppColors.successDone.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasStreak
                        ? AppColors.successDone.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  hasStreak ? 'Active 🔥' : 'Start Today',
                  style: AppTypography.tagChip.copyWith(
                    color: hasStreak ? AppColors.successDone : AppColors.textPlaceholder,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content Row: Pulsing Flame Icon + Streak Count & Subtitle
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PulsingFlameIcon(isActive: hasStreak),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          _AnimatedNumberText(
                            value: widget.currentStreak.toDouble(),
                            style: AppTypography.displayHeading.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            widget.currentStreak == 1 ? ' Day Streak' : ' Days Streak',
                            style: AppTypography.displayHeading.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasStreak
                          ? 'Best: ${widget.bestStreak} days · Keep the momentum going'
                          : 'Complete today\'s routine and close day to start',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Micro Stats Footer (3 Equal Columns with FittedBox, Zero Overflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.appBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMicroStat(
                    icon: Icons.done_all_rounded,
                    label: 'Logged',
                    value: '${widget.weeklyLogs.length}/7 this wk',
                    color: AppColors.accentPrimary,
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(
                  child: _buildMicroStat(
                    icon: Icons.military_tech_rounded,
                    label: 'Best Streak',
                    value: '${widget.bestStreak} days',
                    color: AppColors.warningTag,
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(
                  child: _buildMicroStat(
                    icon: Icons.offline_bolt_rounded,
                    label: 'Score',
                    value: widget.logs.isNotEmpty ? '${(widget.weeklyScore).toInt()}%' : '0%',
                    color: AppColors.successDone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.sectionLabel.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textPlaceholder,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.scoreStat.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekly Health Score Ring Card ───────────────────────────────────────────
  Widget _buildHealthScoreCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WEEKLY ROUTINE SCORE', style: AppTypography.sectionLabel),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.weeklyLogs.length} / 7 days logged',
                  style: AppTypography.tagChip.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HealthScoreRing(score: widget.weeklyScore, grade: widget.grade),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.appBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Icon(
                  widget.weeklyScore >= 80 ? Icons.auto_awesome : Icons.info_outline_rounded,
                  size: 16,
                  color: widget.weeklyScore >= 80 ? AppColors.warningTag : AppColors.accentPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.weeklyScore >= 80
                        ? 'Disciplined execution this week! Keep your momentum steady.'
                        : 'Complete your morning habits early to elevate your score.',
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Energy Trends Bar Chart Card ────────────────────────────────────────────
  Widget _buildEnergyChartCard() {
    final now = DateTime.now();
    final startOfWeek = AppDateConstants.startOfWeek(now);
    List<BarChartGroupData> barGroups = [];

    double totalEnergy = 0;
    int loggedEnergyCount = 0;

    for (int i = 0; i < 7; i++) {
      final d = startOfWeek.add(Duration(days: i));
      final log = widget.weeklyLogs
          .where((l) =>
              l.date.year == d.year &&
              l.date.month == d.month &&
              l.date.day == d.day)
          .firstOrNull;
      final isToday = d.year == now.year && d.month == now.month && d.day == now.day;

      if (log != null && log.energyLevel > 0) {
        totalEnergy += log.energyLevel;
        loggedEnergyCount++;
      }

      final barVal = log?.energyLevel.toDouble() ?? 0.0;

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: barVal,
            color: isToday
                ? AppColors.accentPrimary
                : (barVal > 0 ? AppColors.accentPrimary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
            width: 18,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 10,
              color: Colors.white.withValues(alpha: 0.02),
            ),
          )
        ],
      ));
    }

    final avgEnergy = loggedEnergyCount > 0 ? (totalEnergy / loggedEnergyCount) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ENERGY LEVELS (SUN–SAT)', style: AppTypography.sectionLabel),
              Text(
                loggedEnergyCount > 0
                    ? 'Avg: ${avgEnergy.toStringAsFixed(1)} / 10'
                    : '1–10 Scale',
                style: AppTypography.scoreStat.copyWith(
                  fontSize: 11.5,
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.cardHoverActive,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      'Level ${rod.toY.toInt()}/10',
                      AppTypography.scoreStat.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final days = AppDateConstants.shortDays;
                        final idx = value.toInt();
                        if (idx < 0 || idx >= days.length) return const SizedBox();
                        final isToday = idx == (now.weekday % 7);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[idx],
                            style: AppTypography.sectionLabel.copyWith(
                              color: isToday ? AppColors.accentPrimary : AppColors.textPlaceholder,
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Aligned 7-Column Consistency Calendar Heatmap ───────────────────────────
  Widget _buildConsistencyMapCard() {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7;
    final endOfWeek = DateTime(now.year, now.month, now.day).add(Duration(days: 6 - daysSinceSunday));
    final days = List.generate(
      35,
      (i) => endOfWeek.subtract(Duration(days: 34 - i)),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CONSISTENCY (LAST 35 DAYS)', style: AppTypography.sectionLabel),
              Text(
                '${widget.logs.length} logged',
                style: AppTypography.scoreStat.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Weekday Column Headers: Sun, Mon, Tue, Wed, Thu, Fri, Sat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: AppDateConstants.dayInitials.map((initial) {
              return Expanded(
                child: Center(
                  child: Text(
                    initial,
                    style: AppTypography.sectionLabel.copyWith(
                      fontSize: 10,
                      color: AppColors.textPlaceholder,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // 5 Rows of 7 Days Each (Pixel-Perfect Alignment)
          Column(
            children: List.generate(5, (weekIdx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (dayIdx) {
                    final day = days[weekIdx * 7 + dayIdx];
                    final logEntry = widget.logs
                        .where((l) =>
                            l.date.year == day.year &&
                            l.date.month == day.month &&
                            l.date.day == day.day)
                        .firstOrNull;

                    Color blockColor = Colors.white.withValues(alpha: 0.06);
                    if (logEntry != null) {
                      if (logEntry.healthScore >= 75) {
                        blockColor = AppColors.successDone;
                      } else if (logEntry.healthScore >= 50) {
                        blockColor = AppColors.successDone.withValues(alpha: 0.6);
                      } else {
                        blockColor = AppColors.successDone.withValues(alpha: 0.25);
                      }
                    }

                    final isSelected = _selectedHeatmapDay != null &&
                        _selectedHeatmapDay!.year == day.year &&
                        _selectedHeatmapDay!.month == day.month &&
                        _selectedHeatmapDay!.day == day.day;

                    return Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isSelected) {
                                _selectedHeatmapDay = null;
                                _selectedHeatmapLog = null;
                              } else {
                                _selectedHeatmapDay = day;
                                _selectedHeatmapLog = logEntry;
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: blockColor,
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: blockColor.withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),

          // Interactive Day Preview Pill
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _selectedHeatmapDay == null
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.appBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedHeatmapLog != null
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: _selectedHeatmapLog != null
                              ? AppColors.successDone
                              : AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, MMM d').format(_selectedHeatmapDay!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle.copyWith(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedHeatmapLog != null
                              ? 'Score: ${_selectedHeatmapLog!.healthScore.toStringAsFixed(0)} · ⚡ ${_selectedHeatmapLog!.energyLevel}/10'
                              : 'No log recorded',
                          style: AppTypography.scoreStat.copyWith(
                            color: _selectedHeatmapLog != null
                                ? AppColors.accentPrimary
                                : AppColors.textPlaceholder,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 14),

          // GitHub Style Intensity Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: AppTypography.tagChip.copyWith(fontSize: 10, color: AppColors.textPlaceholder)),
              const SizedBox(width: 6),
              _buildLegendDot(Colors.white.withValues(alpha: 0.06)),
              const SizedBox(width: 4),
              _buildLegendDot(AppColors.successDone.withValues(alpha: 0.25)),
              const SizedBox(width: 4),
              _buildLegendDot(AppColors.successDone.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              _buildLegendDot(AppColors.successDone),
              const SizedBox(width: 6),
              Text('More', style: AppTypography.tagChip.copyWith(fontSize: 10, color: AppColors.textPlaceholder)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ─── Pulsing Flame Widget ─────────────────────────────────────────────────────

class _PulsingFlameIcon extends StatefulWidget {
  final bool isActive;
  const _PulsingFlameIcon({required this.isActive});

  @override
  State<_PulsingFlameIcon> createState() => _PulsingFlameIconState();
}

class _PulsingFlameIconState extends State<_PulsingFlameIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingFlameIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isActive && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.isActive ? _scaleAnim : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.adHocTask.withValues(alpha: widget.isActive ? 0.16 : 0.08),
          shape: BoxShape.circle,
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: AppColors.adHocTask.withValues(alpha: 0.3),
                    blurRadius: 14,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Icon(
          Icons.local_fire_department_rounded,
          color: AppColors.adHocTask,
          size: 28,
        ),
      ),
    );
  }
}

// ─── Wallet & Finance View ────────────────────────────────────────────────────

class _WalletView extends ConsumerStatefulWidget {
  const _WalletView({super.key});

  @override
  ConsumerState<_WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends ConsumerState<_WalletView> {
  int _touchedDonutIndex = -1;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(currentMonthSummaryProvider);
    final txs = ref.watch(currentTransactionsProvider);
    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings = settingsBox.isNotEmpty ? settingsBox.getAt(0) : null;

    final income = summary?.totalIncome ?? 0.0;
    final spent = summary?.totalExpense ?? 0.0;
    final opening = summary?.openingBalance ?? 0.0;
    final saved = (income - spent + opening).clamp(0.0, double.infinity);
    final semGoal = settings?.semesterGoal ?? 0.0;
    final monthlyBudget = settings?.monthlyBudget ?? 0.0;

    final now = DateTime.now();
    final repo = ref.watch(eodRepoProvider);
    final monthLogs = repo.getLogsForMonth(now.year, now.month);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 0. Safe Daily Spend Hero Card ────────────────────────────
          if (monthlyBudget > 0) ...[
            _StaggeredCard(
              index: 0,
              child: _buildSafeDailySpendCard(now, spent, monthlyBudget),
            ),
            const SizedBox(height: 16),
          ],

          // ── 1. Interactive Category Spending Donut Chart ─────────────
          _StaggeredCard(
            index: 1,
            child: _buildCategoryDonutCard(txs),
          ),
          const SizedBox(height: 16),

          // ── 2. Daily Spending Trend Bar Chart ────────────────────────
          const _StaggeredCard(
            index: 2,
            child: DailySpendingChart(),
          ),
          const SizedBox(height: 16),

          // ── 3. Income vs Spend & Cash Flow Bar Chart ─────────────────
          _StaggeredCard(
            index: 3,
            child: _buildIncomeSpendCard(income, spent),
          ),
          const SizedBox(height: 16),

          // ── 4. Semester Savings Goal Card ────────────────────────────
          _StaggeredCard(
            index: 4,
            child: _buildSavingsCard(saved, semGoal),
          ),
          const SizedBox(height: 16),

          // ── 5. Budget Discipline Indicator ───────────────────────────
          _StaggeredCard(
            index: 5,
            child: _buildBudgetDisciplineCard(monthLogs),
          ),
        ],
      ),
    );
  }

  // ── Safe Daily Spend Hero Card (No Overflow & Clean Alignment) ──────────────
  Widget _buildSafeDailySpendCard(DateTime now, double spent, double monthlyBudget) {
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final daysRemaining = (daysInMonth - now.day).clamp(1, 31);
    final remainingBudget = (monthlyBudget - spent).clamp(0.0, double.infinity);
    final safeDaily = remainingBudget / daysRemaining;

    final isOver = spent > monthlyBudget;
    final pctUsed = (spent / monthlyBudget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOver
              ? AppColors.errorAlert.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('DAILY SPENDING PACING', style: AppTypography.sectionLabel),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOver ? AppColors.errorAlert : AppColors.successDone).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOver ? 'Exceeded' : 'On Track',
                  style: AppTypography.tagChip.copyWith(
                    color: isOver ? AppColors.errorAlert : AppColors.successDone,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _AnimatedNumberText(
                  value: safeDaily,
                  style: AppTypography.displayHeading.copyWith(
                    fontSize: 32,
                    letterSpacing: -0.6,
                    color: isOver ? AppColors.errorAlert : AppColors.textPrimary,
                  ),
                  prefix: '৳',
                ),
                const SizedBox(width: 6),
                Text(
                  '/ day safe limit',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOver
                ? 'You are ৳${NumberFormat('#,##0').format((spent - monthlyBudget).toInt())} over your monthly limit'
                : 'Based on ৳${NumberFormat('#,##0').format(remainingBudget.toInt())} remaining for $daysRemaining days',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyText.copyWith(
              color: isOver ? AppColors.errorAlert : AppColors.textMuted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          // Animated Progress Bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: pctUsed),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animatedPct, _) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: animatedPct,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOver
                            ? AppColors.errorAlert
                            : (animatedPct > 0.85 ? AppColors.warningTag : AppColors.accentPrimary),
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '৳${NumberFormat('#,##0').format(spent.toInt())} spent (${(animatedPct * 100).toInt()}%)',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.tagChip.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Budget: ৳${NumberFormat('#,##0').format(monthlyBudget.toInt())}',
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: AppTypography.tagChip.copyWith(
                            fontSize: 11,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Interactive Category Donut Chart (Text Fully Contained in Donut) ─────────
  Widget _buildCategoryDonutCard(List<Transaction> txs) {
    final expenseTxs = txs
        .where((t) =>
            t.direction == Direction.expense &&
            t.expenseType != ExpenseType.borrowed &&
            t.expenseType != ExpenseType.lent)
        .toList();

    if (expenseTxs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            Text('SPENDING BY CATEGORY', style: AppTypography.sectionLabel),
            const SizedBox(height: 16),
            Icon(Icons.pie_chart_outline_rounded, size: 38, color: AppColors.textPlaceholder),
            const SizedBox(height: 10),
            Text('No expenses recorded this month', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    final Map<ExpenseType, double> catTotals = {};
    double totalExpense = 0;
    for (var tx in expenseTxs) {
      final type = tx.expenseType ?? ExpenseType.other;
      catTotals[type] = (catTotals[type] ?? 0.0) + tx.amount;
      totalExpense += tx.amount;
    }

    final colors = [
      AppColors.accentPrimary,
      AppColors.successDone,
      AppColors.warningTag,
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    int colorIdx = 0;
    final List<PieChartSectionData> sections = [];
    final List<Map<String, dynamic>> catItems = [];

    catTotals.forEach((type, amount) {
      final color = colors[colorIdx % colors.length];
      final isTouched = colorIdx == _touchedDonutIndex;
      final pct = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

      catItems.add({
        'name': type.name.toUpperCase(),
        'amount': amount,
        'color': color,
        'pct': pct,
        'index': colorIdx,
      });

      sections.add(
        PieChartSectionData(
          value: amount,
          color: color,
          radius: isTouched ? 24 : 18,
          showTitle: false,
        ),
      );
      colorIdx++;
    });

    final activeItem = (_touchedDonutIndex >= 0 && _touchedDonutIndex < catItems.length)
        ? catItems[_touchedDonutIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SPENDING BY CATEGORY', style: AppTypography.sectionLabel),
              Text(
                '৳${NumberFormat('#,##0').format(totalExpense.toInt())} Total',
                style: AppTypography.scoreStat.copyWith(
                  color: AppColors.accentPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart with touch interaction
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 46,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedDonutIndex = -1;
                            return;
                          }
                          _touchedDonutIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                ),

                // Center info display (Sized to fit perfectly inside center hole without overflow)
                SizedBox(
                  width: 78,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: activeItem != null
                        ? Column(
                            key: ValueKey('touched_${activeItem['name']}'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '৳${NumberFormat('#,##0').format((activeItem['amount'] as double).toInt())}',
                                  style: AppTypography.headline.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: activeItem['color'] as Color,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${activeItem['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyText.copyWith(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPlaceholder,
                                ),
                              ),
                              Text(
                                '${(activeItem['pct'] as double).toStringAsFixed(0)}%',
                                style: AppTypography.scoreStat.copyWith(
                                  fontSize: 10,
                                  color: activeItem['color'] as Color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('default_total'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '৳${NumberFormat('#,##0').format(totalExpense.toInt())}',
                                  style: AppTypography.headline.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Spent',
                                style: AppTypography.bodyText.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Legend Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: catItems.map((item) {
              final isTouched = item['index'] == _touchedDonutIndex;
              final Color color = item['color'];

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _touchedDonutIndex = isTouched ? -1 : (item['index'] as int);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTouched ? color.withValues(alpha: 0.22) : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTouched ? color : color.withValues(alpha: 0.25),
                      width: isTouched ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item['name']} · ${(item['pct'] as double).toStringAsFixed(0)}%',
                        style: AppTypography.tagChip.copyWith(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Income vs Spend Bar Chart Card (Pixel-Perfect Stat Pills) ───────────────
  Widget _buildIncomeSpendCard(double income, double spent) {
    final maxY = (income > spent ? income : spent) * 1.2;
    final safeMax = maxY <= 0 ? 100.0 : maxY;
    final net = income - spent;
    final isSurplus = net >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('INCOME VS SPEND', style: AppTypography.sectionLabel),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSurplus ? AppColors.successDone : AppColors.errorAlert).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
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
                      isSurplus ? 'Net Surplus' : 'Net Deficit',
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
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: safeMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.cardHoverActive,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      '৳${NumberFormat('#,##0').format(rod.toY.toInt())}',
                      AppTypography.scoreStat.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Income', 'Spent'];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[idx],
                            style: AppTypography.sectionLabel.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
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
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: income,
                      color: AppColors.successDone,
                      width: 38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: spent,
                      color: AppColors.warningTag,
                      width: 38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 3 Uniformly Sized & Aligned Stat Pills
          Row(
            children: [
              _StatPill('Income', income, AppColors.successDone),
              const SizedBox(width: 8),
              _StatPill('Spent', spent, AppColors.warningTag),
              const SizedBox(width: 8),
              _StatPill(
                'Net',
                net,
                isSurplus ? AppColors.successDone : AppColors.errorAlert,
                isNet: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Semester Savings Goal Card ──────────────────────────────────────────────
  Widget _buildSavingsCard(double saved, double semGoal) {
    if (semGoal <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Set a semester savings goal in Profile to track it here.',
                style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 13),
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SEMESTER SAVINGS GOAL', style: AppTypography.sectionLabel),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: AppTypography.tagChip.copyWith(
                  color: AppColors.accentPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: val,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                  minHeight: 8,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  currencyFormat.format(saved),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.scoreStat.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'Goal: ${currencyFormat.format(semGoal)}',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Budget Discipline Indicator Card ────────────────────────────────────────
  Widget _buildBudgetDisciplineCard(List<EODLog> monthLogs) {
    final answered = monthLogs.where((l) => l.stuckToBudget != null).toList();
    final answeredCount = answered.length;
    final stuckCount = answered.where((l) => l.stuckToBudget == true).length;
    final rate = answeredCount > 0 ? (stuckCount / answeredCount) : 0.0;
    final color = rate >= 0.70 ? AppColors.successDone : AppColors.warningTag;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BUDGET DISCIPLINE RATE', style: AppTypography.sectionLabel),
              if (answeredCount > 0)
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: AppTypography.scoreStat.copyWith(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (answeredCount == 0)
            Text(
              'Answer the budget check-in during EOD close-day to track monthly discipline here.',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            )
          else ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: rate),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: val,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$stuckCount of $answeredCount days adhered to daily budget',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyText.copyWith(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stat Pill (Fixed Height & Unified Layout) ────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isNet;

  const _StatPill(this.label, this.value, this.color, {this.isNet = false});

  @override
  Widget build(BuildContext context) {
    final prefix = isNet ? (value >= 0 ? '+৳' : '-৳') : '৳';
    final formatted = '$prefix${NumberFormat('#,##0').format(value.abs().toInt())}';

    return Expanded(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sectionLabel.copyWith(
                color: color,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatted,
                style: AppTypography.scoreStat.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
