import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/eod_log.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../widgets/action_button.dart';
import '../../widgets/app_back_button.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/review_providers.dart';
export '../../providers/review_providers.dart' show eodRepoProvider;
import '../../services/routine_health_score_service.dart';

class EODLogScreen extends ConsumerStatefulWidget {
  final EODLog? savedLog;
  const EODLogScreen({super.key, this.savedLog});

  @override
  ConsumerState<EODLogScreen> createState() => _EODLogScreenState();
}

class _EODLogScreenState extends ConsumerState<EODLogScreen> {
  int _energyLevel = 5;
  String _motivation = 'Medium';
  bool? _stuckToBudget; // null = not yet answered
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildMotivationChip(String label, Color activeColor) {
    final isRetro = AppColors.isRetro;
    final isActive = _motivation == label;
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label motivation',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _motivation = label);
        },
        child: AnimatedContainer(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isRetro ? 14 : 16,
            vertical: isRetro ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: isRetro ? 0.25 : 0.16)
                : AppColors.cardBackground,
            borderRadius: isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? activeColor : AppColors.cardBorder,
              width: isRetro ? 1.5 : 1.0,
            ),
            boxShadow: isRetro && isActive
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: (isRetro
                    ? RetroTypography.buttonLabel
                    : AppTypography.tagChip)
                .copyWith(
              color: isActive ? activeColor : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: isRetro ? 10 : 12.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final now = DateTime.now();

    final todayLog = widget.savedLog ?? ref.watch(todayReviewProvider);

    if (todayLog != null) {
      return _buildReadOnlyView(todayLog);
    }

    final tasks = ref.watch(todayTasksProvider);
    final repo = ref.watch(eodRepoProvider);

    final scoreMap = RoutineHealthScoreService().calculateDailyScore(tasks);
    final grade = scoreMap['grade'] as String;
    final score = scoreMap['score'] as double;

    final completed = tasks
        .where((t) => !t.isBufferBlock && t.status == TaskStatus.done)
        .length;
    final total = tasks.where((t) => !t.isBufferBlock).length;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Center(child: AppBackButton()),
        ),
        title: Text(
          'Review Day',
          style: AppTypography.displayHeading.copyWith(
            fontSize: isRetro ? 15 : 22,
            letterSpacing: isRetro ? 0.0 : -0.4,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreCard(grade, score, completed, total),
            const SizedBox(height: 14),
            Text(
              DateFormat.yMMMMd().format(now),
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: isRetro ? 12 : 13.5,
              ),
            ),
            const SizedBox(height: 24),

            // Energy Level
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('ENERGY LEVEL', style: AppTypography.sectionLabel),
                Text(
                  '$_energyLevel / 10',
                  style: AppTypography.scoreStat.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: isRetro ? 16 : 13,
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
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(14),
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
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accentPrimary,
                  inactiveTrackColor: isRetro
                      ? AppColors.cardHoverActive
                      : AppColors.subtleBorder,
                  thumbColor: AppColors.accentPrimary,
                  overlayColor: AppColors.accentPrimary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  semanticFormatterCallback: (value) =>
                      'Energy ${value.round()} of 10',
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMotivationChip('Low', AppColors.warningTag),
                _buildMotivationChip('Medium', AppColors.accentPrimary),
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
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you stick to your daily budget today?',
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: isRetro ? 11.5 : 13.5,
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
                          activeBg: AppColors.successDone.withValues(
                            alpha: isRetro ? 0.25 : 0.14,
                          ),
                          activeFg: AppColors.successDone,
                          onTap: () => setState(() => _stuckToBudget = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BudgetChoiceButton(
                          label: 'No, went over',
                          active: _stuckToBudget == false,
                          activeBg: AppColors.warningTag.withValues(
                            alpha: isRetro ? 0.25 : 0.14,
                          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(14),
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
              child: TextField(
                controller: _notesController,
                maxLines: 4,
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: isRetro ? 12 : 14,
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'How did today go? Any notes, wins, or thoughts...',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: isRetro ? 11.5 : 13,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            ActionButton(
              label: _saving ? 'Saving Review...' : 'Save Review',
              icon: Icons.check_circle_rounded,
              isPrimary: true,
              isLoading: _saving,
              onTap: _saving
                  ? null
                  : () async {
                      if (_saving) return;
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(todayTasksProvider.notifier)
                            .loadTodayTasks();
                        if (!mounted) return;
                        final submittedAt = DateTime.now();
                        final snapshot = ref.read(todayTasksProvider);
                        final snapshotScore = RoutineHealthScoreService()
                            .calculateDailyScore(snapshot);
                        final log = EODLog(
                          id: const Uuid().v4(),
                          date: DateTime(
                            submittedAt.year,
                            submittedAt.month,
                            submittedAt.day,
                          ),
                          totalTasks: snapshot
                              .where((t) => !t.isBufferBlock)
                              .length,
                          completedTasks: snapshot
                              .where(
                                (t) =>
                                    !t.isBufferBlock &&
                                    t.status == TaskStatus.done,
                              )
                              .length,
                          skippedTasks: snapshot
                              .where(
                                (t) =>
                                    !t.isBufferBlock &&
                                    t.status == TaskStatus.skipped,
                              )
                              .length,
                          rescheduledTasks: snapshotScore['rescheduled'] as int,
                          userNote: _notesController.text.trim(),
                          closedAt: submittedAt,
                          healthScore: snapshotScore['score'] as double,
                          grade: snapshotScore['grade'] as String,
                          energyLevel: _energyLevel,
                          motivation: _motivation,
                          stuckToBudget: _stuckToBudget,
                        );
                        await repo.save(log);
                        HapticFeedback.mediumImpact();
                        if (!mounted) return;
                        ref.invalidate(reviewHistoryProvider);
                        if (mounted) setState(() {});
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save the review. Your answers are kept; please retry.',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String grade, double score, int completed, int total) {
    final isRetro = AppColors.isRetro;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro
            ? BorderRadius.zero
            : BorderRadius.circular(18),
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
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DAILY GRADE', style: AppTypography.sectionLabel),
              const SizedBox(height: 6),
              Text(
                grade,
                style: AppTypography.displayHeading.copyWith(
                  color: AppColors.successDone,
                  fontSize: isRetro ? 28 : 36,
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
                  fontSize: isRetro ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${score.toStringAsFixed(1)}% Health Score',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: isRetro ? 10.5 : 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyView(EODLog todayLog) {
    final isRetro = AppColors.isRetro;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Center(child: AppBackButton()),
        ),
        title: Text(
          'Saved Review',
          style: AppTypography.displayHeading.copyWith(
            fontSize: isRetro ? 15 : 22,
            letterSpacing: isRetro ? 0.0 : -0.4,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DateFormat.yMMMMEEEEd().format(todayLog.date),
              style: AppTypography.cardTitle.copyWith(
                fontSize: isRetro ? 12.5 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Submitted ${DateFormat.yMMMd().add_jm().format(todayLog.closedAt)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: isRetro ? 10 : 11.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildScoreCard(
              todayLog.grade,
              todayLog.healthScore,
              todayLog.completedTasks,
              todayLog.totalTasks,
            ),
            const SizedBox(height: 12),
            Text(
              '${todayLog.skippedTasks} skipped · ${todayLog.rescheduledTasks} rescheduled',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textMuted,
                fontSize: isRetro ? 11 : 12.5,
              ),
            ),
            const SizedBox(height: 18),

            // Energy + Motivation + Budget row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(16),
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
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 100,
                    child: _ReadOnlyStat(
                      icon: Icons.bolt_rounded,
                      label: 'ENERGY',
                      value: '${todayLog.energyLevel} / 10',
                      color: AppColors.accentPrimary,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: _ReadOnlyStat(
                      icon: Icons.trending_up_rounded,
                      label: 'MOTIVATION',
                      value: todayLog.motivation,
                      color: _motivationColor(todayLog.motivation),
                    ),
                  ),
                  if (todayLog.stuckToBudget != null) ...[
                    SizedBox(
                      width: 100,
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
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REFLECTION NOTES', style: AppTypography.sectionLabel),
                    const SizedBox(height: 10),
                    Text(
                      todayLog.userNote!,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: isRetro ? 12 : 13.5,
                        height: 1.4,
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
    final isRetro = AppColors.isRetro;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          constraints: const BoxConstraints(minHeight: 46),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? activeBg : AppColors.cardHoverActive,
            borderRadius: isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(12),
            border: Border.all(
              color: active ? activeFg : AppColors.cardBorder,
              width: isRetro ? 1.5 : 1.0,
            ),
            boxShadow: isRetro && active
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: (isRetro
                      ? RetroTypography.buttonLabel
                      : AppTypography.buttonLabel)
                  .copyWith(
                color: active ? activeFg : AppColors.textSecondary,
                fontSize: isRetro ? 9.5 : 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
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
    final isRetro = AppColors.isRetro;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTypography.sectionLabel.copyWith(
            fontSize: isRetro ? 8 : 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.scoreStat.copyWith(
            color: color,
            fontSize: isRetro ? 15 : 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
