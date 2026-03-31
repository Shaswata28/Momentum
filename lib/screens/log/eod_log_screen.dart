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

  Widget _buildMotivationChip(String label, Color activeColor) {
    final isActive = _motivation == label;
    return GestureDetector(
      onTap: () => setState(() => _motivation = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: AppTypography.tagChip
                .copyWith(color: isActive ? Colors.white : AppColors.textSecondary)),
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
        title: Text('End of Day Log', style: AppTypography.displayHeading),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreCard(grade, score, completed, total),
            const SizedBox(height: 32),

            // Energy slider
            Text('Energy Level: $_energyLevel', style: AppTypography.cardTitle),
            Slider(
              value: _energyLevel.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.accentPrimary,
              inactiveColor: AppColors.cardBackground,
              onChanged: (val) => setState(() => _energyLevel = val.toInt()),
            ),
            const SizedBox(height: 24),

            // Motivation chips
            Text('Motivation', style: AppTypography.cardTitle),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMotivationChip('Low', AppColors.warningFloating),
                const SizedBox(width: 8),
                _buildMotivationChip('Medium', AppColors.accentPrimary),
                const SizedBox(width: 8),
                _buildMotivationChip('High', AppColors.successDone),
              ],
            ),
            const SizedBox(height: 32),

            // ── Financial Check-In ────────────────────────────────────────
            Text(
              'FINANCIAL CHECK-IN',
              style: AppTypography.sectionLabel.copyWith(color: const Color(0xFF666672)),
            ),
            const SizedBox(height: 10),
            Text(
              'Did you stick to your budget today?',
              style: AppTypography.bodyText
                  .copyWith(color: const Color(0xFFD8D8E8), fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BudgetChoiceButton(
                    label: 'Yes',
                    active: _stuckToBudget == true,
                    activeBg: const Color(0xFF0D2010),
                    activeFg: const Color(0xFF1D9E75),
                    onTap: () => setState(() => _stuckToBudget = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BudgetChoiceButton(
                    label: 'No',
                    active: _stuckToBudget == false,
                    activeBg: const Color(0xFF201008),
                    activeFg: const Color(0xFFF5A623),
                    onTap: () => setState(() => _stuckToBudget = false),
                  ),
                ),
              ],
            ),
            // ─────────────────────────────────────────────────────────────
            const SizedBox(height: 32),

            // Daily Reflection notes
            Text('Notes', style: AppTypography.cardTitle),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: AppTypography.bodyText,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                hintText: 'How did today go?',
                hintStyle: AppTypography.sectionLabel,
              ),
            ),
            const SizedBox(height: 48),

            ActionButton(
              label: 'Save Log',
              onTap: () async {
                HapticFeedback.mediumImpact();
                final log = EODLog(
                  id: const Uuid().v4(),
                  date: now,
                  totalTasks: total,
                  completedTasks: completed,
                  skippedTasks: skipped,
                  rescheduledTasks: rescheduledCount,
                  userNote: _notesController.text,
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
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String grade, double score, int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerBorderHover),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily Grade', style: AppTypography.sectionLabel),
              Text(grade,
                  style: AppTypography.displayHeading
                      .copyWith(color: AppColors.successDone, fontSize: 32)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Tasks', style: AppTypography.sectionLabel),
              Text('$completed / $total',
                  style: AppTypography.cardTime.copyWith(fontSize: 16)),
              Text('${score.toStringAsFixed(1)}% Health',
                  style: AppTypography.scoreStat),
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
        title: Text("Today's Log", style: AppTypography.displayHeading),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreCard(todayLog.grade, todayLog.healthScore,
                todayLog.completedTasks, todayLog.totalTasks),
            const SizedBox(height: 16),

            // Energy + Motivation row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dividerBorderHover),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ReadOnlyStat(
                      icon: Icons.bolt_outlined,
                      label: 'ENERGY',
                      value: '${todayLog.energyLevel} / 10',
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppColors.dividerBorderHover),
                  Expanded(
                    child: _ReadOnlyStat(
                      icon: Icons.trending_up_outlined,
                      label: 'MOTIVATION',
                      value: todayLog.motivation,
                      color: _motivationColor(todayLog.motivation),
                    ),
                  ),
                  if (todayLog.stuckToBudget != null) ...[
                    Container(width: 1, height: 40, color: AppColors.dividerBorderHover),
                    Expanded(
                      child: _ReadOnlyStat(
                        icon: todayLog.stuckToBudget!
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.dividerBorderHover),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NOTES', style: AppTypography.sectionLabel),
                    const SizedBox(height: 10),
                    Text(todayLog.userNote!, style: AppTypography.bodyText),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Color _motivationColor(String motivation) {
    switch (motivation) {
      case 'High': return AppColors.successDone;
      case 'Low':  return AppColors.warningTag;
      default:     return AppColors.accentPrimary;
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? activeBg : const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeFg : const Color(0xFF2A2A38),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.buttonLabel.copyWith(
            color: active ? activeFg : const Color(0xFF666672),
            fontSize: 14,
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
        Text(label, style: AppTypography.sectionLabel.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.scoreStat.copyWith(color: color, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
