import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/eod_log.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/action_button.dart';
import '../../providers/dashboard_providers.dart';
import '../../repositories/eod_log_repository.dart';
import '../../services/routine_health_score_service.dart';

final eodRepoProvider = Provider((ref) => EODLogRepository());

class EODLogScreen extends ConsumerStatefulWidget {
  const EODLogScreen({super.key});

  @override
  ConsumerState<EODLogScreen> createState() => _EODLogScreenState();
}

class _EODLogScreenState extends ConsumerState<EODLogScreen> {
  int _energyLevel = 5;
  String _motivation = 'Medium';
  bool? _stuckToBudget; // null = not yet answered
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildMotivationChip(String label, Color activeColor) {
    final isActive = _motivation == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _motivation = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.16) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.06),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.tagChip.copyWith(
            color: isActive ? activeColor : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(todayTasksProvider);
    final repo = ref.watch(eodRepoProvider);
    final now = DateTime.now();

    final logs = repo.getAllLogs();
    final todayLog = logs
        .where((l) =>
            l.date.year == now.year &&
            l.date.month == now.month &&
            l.date.day == now.day)
        .firstOrNull;

    if (todayLog != null) {
      return _buildReadOnlyView(todayLog);
    }

    final scoreMap = RoutineHealthScoreService().calculateDailyScore(tasks);
    final grade = scoreMap['grade'] as String;
    final score = scoreMap['score'] as double;
    final rescheduledCount = scoreMap['rescheduled'] as int;

    final completed = tasks.where((t) => !t.isBufferBlock && t.status == TaskStatus.done).length;
    final total = tasks.where((t) => !t.isBufferBlock).length;
    final skipped = tasks.where((t) => !t.isBufferBlock && t.status == TaskStatus.skipped).length;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        title: Text('End of Day Log', style: AppTypography.displayHeading.copyWith(fontSize: 22)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreCard(grade, score, completed, total),
            const SizedBox(height: 24),

            // Energy Level
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ENERGY LEVEL', style: AppTypography.sectionLabel),
                Text(
                  '$_energyLevel / 10',
                  style: AppTypography.scoreStat.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accentPrimary,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                  thumbColor: Colors.white,
                  overlayColor: AppColors.accentPrimary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _energyLevel.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _energyLevel = val.toInt());
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Motivation
            Text('MOTIVATION', style: AppTypography.sectionLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMotivationChip('Low', AppColors.warningTag),
                const SizedBox(width: 10),
                _buildMotivationChip('Medium', AppColors.accentPrimary),
                const SizedBox(width: 10),
                _buildMotivationChip('High', AppColors.successDone),
              ],
            ),
            const SizedBox(height: 24),

            // Financial Check-In
            Text('FINANCIAL CHECK-IN', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you stick to your daily budget today?',
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BudgetChoiceButton(
                          label: 'Yes, on track',
                          active: _stuckToBudget == true,
                          activeBg: AppColors.successDone.withValues(alpha: 0.14),
                          activeFg: AppColors.successDone,
                          onTap: () => setState(() => _stuckToBudget = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BudgetChoiceButton(
                          label: 'No, went over',
                          active: _stuckToBudget == false,
                          activeBg: AppColors.warningTag.withValues(alpha: 0.14),
                          activeFg: AppColors.warningTag,
                          onTap: () => setState(() => _stuckToBudget = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Daily Reflection Notes
            Text('DAILY REFLECTION', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'How did today go? Any notes, wins, or thoughts...',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            ActionButton(
              label: 'Save End of Day Log',
              icon: Icons.check_circle_rounded,
              isPrimary: true,
              onTap: () async {
                HapticFeedback.mediumImpact();
                final log = EODLog(
                  id: const Uuid().v4(),
                  date: now,
                  totalTasks: total,
                  completedTasks: completed,
                  skippedTasks: skipped,
                  rescheduledTasks: rescheduledCount,
                  userNote: _notesController.text.trim(),
                  closedAt: now,
                  healthScore: score,
                  grade: grade,
                  energyLevel: _energyLevel,
                  motivation: _motivation,
                  stuckToBudget: _stuckToBudget,
                );
                await repo.save(log);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String grade, double score, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DAILY GRADE', style: AppTypography.sectionLabel),
              const SizedBox(height: 4),
              Text(
                grade,
                style: AppTypography.displayHeading.copyWith(
                  color: AppColors.successDone,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('TASKS COMPLETED', style: AppTypography.sectionLabel),
              const SizedBox(height: 4),
              Text(
                '$completed of $total done',
                style: AppTypography.scoreStat.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${score.toStringAsFixed(1)}% Health Score',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyView(EODLog todayLog) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        title: Text("Today's Log", style: AppTypography.displayHeading.copyWith(fontSize: 22)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreCard(
              todayLog.grade,
              todayLog.healthScore,
              todayLog.completedTasks,
              todayLog.totalTasks,
            ),
            const SizedBox(height: 18),

            // Energy + Motivation + Budget row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ReadOnlyStat(
                      icon: Icons.bolt_rounded,
                      label: 'ENERGY',
                      value: '${todayLog.energyLevel} / 10',
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  Container(width: 1, height: 38, color: Colors.white.withValues(alpha: 0.06)),
                  Expanded(
                    child: _ReadOnlyStat(
                      icon: Icons.trending_up_rounded,
                      label: 'MOTIVATION',
                      value: todayLog.motivation,
                      color: _motivationColor(todayLog.motivation),
                    ),
                  ),
                  if (todayLog.stuckToBudget != null) ...[
                    Container(width: 1, height: 38, color: Colors.white.withValues(alpha: 0.06)),
                    Expanded(
                      child: _ReadOnlyStat(
                        icon: todayLog.stuckToBudget!
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        label: 'BUDGET',
                        value: todayLog.stuckToBudget! ? 'On track' : 'Over',
                        color: todayLog.stuckToBudget!
                            ? AppColors.successDone
                            : AppColors.warningTag,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (todayLog.userNote?.isNotEmpty ?? false) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.subtleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REFLECTION NOTES', style: AppTypography.sectionLabel),
                    const SizedBox(height: 10),
                    Text(
                      todayLog.userNote!,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _motivationColor(String motivation) {
    switch (motivation) {
      case 'High':
        return AppColors.successDone;
      case 'Low':
        return AppColors.warningTag;
      default:
        return AppColors.accentPrimary;
    }
  }
}

// ─── Budget Choice Button ──────────────────────────────────────────────────────

class _BudgetChoiceButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeBg;
  final Color activeFg;
  final VoidCallback onTap;

  const _BudgetChoiceButton({
    required this.label,
    required this.active,
    required this.activeBg,
    required this.activeFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? activeBg : AppColors.appBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? activeFg : Colors.white.withValues(alpha: 0.08),
            width: active ? 1.4 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.buttonLabel.copyWith(
            color: active ? activeFg : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Read-only stat cell ──────────────────────────────────────────────────────

class _ReadOnlyStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ReadOnlyStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(label, style: AppTypography.sectionLabel.copyWith(fontSize: 10)),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.scoreStat.copyWith(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
