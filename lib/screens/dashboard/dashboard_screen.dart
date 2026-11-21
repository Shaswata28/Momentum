import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/task_card.dart';
import '../../providers/dashboard_providers.dart';
import '../../models/daily_task_instance.dart';
import '../../models/enums.dart';
import '../../models/user_settings.dart';
import '../../widgets/wallet_summary_card.dart';
import '../profile/profile_screen.dart';
import '../routine/routine_builder_screen.dart';
import '../../theme/retro_typography.dart';
import 'package:hive/hive.dart';
import 'quick_add_button.dart';
import '../../services/notification_service.dart';
import '../../providers/review_providers.dart';
import '../../widgets/action_button.dart';
import '../../widgets/staggered_card.dart';

final GlobalKey coachTaskList = GlobalKey();
final GlobalKey coachQuickAdd = GlobalKey();

const _kOverlayColor = Color(0xFF000000);
const _kOverlayOpacity = 0.82;
const _kMovingDuration = Duration(milliseconds: 300);
const _kScaleDuration = Duration(milliseconds: 180);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  BuildContext? _showcaseCtx;
  late final VoidCallback _foregroundAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshToday();
    });

    // Refresh when a foreground notification action completes
    _foregroundAction = () {
      if (mounted) {
        _refreshToday();
      }
    };
    NotificationService.onForegroundAction = _foregroundAction;

    final userSettings = Hive.box<UserSettings>('userSettings').get('user');
    if (userSettings?.hasSeenCoachMarks ?? false) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _showcaseCtx == null) return;
        ShowCaseWidget.of(
          _showcaseCtx!,
        ).startShowCase([coachTaskList, coachQuickAdd]);
      });
    });
  }

  void _markTourSeen() {
    final box = Hive.box<UserSettings>('userSettings');
    final current = box.get('user') ?? UserSettings();
    box.put(
      'user',
      UserSettings(
        firstName: current.firstName,
        avatarIndex: current.avatarIndex,
        isFirstLaunch: current.isFirstLaunch,
        hasSeenCoachMarks: true,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (NotificationService.onForegroundAction == _foregroundAction) {
      NotificationService.onForegroundAction = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(localTimeProvider);
      _refreshToday();
    }
  }

  Future<void> _refreshToday() async {
    try {
      await ref.read(todayTasksProvider.notifier).loadTodayTasks();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh today. Pull down to retry.'),
          ),
        );
      }
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localTimeProvider, (previous, next) {
      if (previous?.valueOrNull != null && next.valueOrNull != null) {
        _refreshToday();
      }
    });
    final localNow = ref.watch(localTimeProvider).valueOrNull ?? DateTime.now();
    final allTasks = ref.watch(todayTasksProvider);
    final activeTasks = ref.watch(activeTasksProvider);
    final completed = ref.watch(completedTasksProvider);

    final totalTasks = allTasks.where((t) => !t.isBufferBlock).length;
    final doneTasks = completed.length;
    final progress = totalTasks > 0 ? (doneTasks / totalTasks) : 0.0;

    final userSettings = Hive.box<UserSettings>('userSettings').get('user');
    final userName = (userSettings?.firstName.isNotEmpty ?? false)
        ? userSettings!.firstName
        : 'Friend';

    final now = localNow;
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    // Split active tasks into Scheduled Timeline and Flexible Window tasks
    final scheduledTasks = <DailyTaskInstance>[];
    final flexibleTasks = <DailyTaskInstance>[];

    for (final task in activeTasks) {
      if (task.scheduledTime != null) {
        scheduledTasks.add(task);
      } else {
        flexibleTasks.add(task);
      }
    }

    // Sort scheduled tasks chronologically
    scheduledTasks.sort((a, b) {
      final aMin = a.scheduledTime!.hour * 60 + a.scheduledTime!.minute;
      final bMin = b.scheduledTime!.hour * 60 + b.scheduledTime!.minute;
      return aMin.compareTo(bMin);
    });

    final isRetro = AppColors.isRetro;
    final descStyle = AppTypography.bodyText.copyWith(
      color: AppColors.textSecondary,
      fontSize: 13,
      height: 1.45,
    );

    return ShowCaseWidget(
      onFinish: _markTourSeen,
      builder: (context) {
        _showcaseCtx = context;
        return Scaffold(
          backgroundColor: AppColors.appBackground,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.accentPrimary,
              backgroundColor: AppColors.cardBackground,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await _refreshToday();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                children: [
                  // ── 0. Header: Greeting + Progress Ring + Settings Gear ────────
                  _StaggeredCard(
                    index: 0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(1);
                        final isNarrow =
                            constraints.maxWidth < 360 || textScale > 1.15;

                        final greetingSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting(),
                              style: AppTypography.sectionLabel.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: isRetro ? 9 : 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                userName,
                                style: AppTypography.displayHeading.copyWith(
                                  fontSize: isRetro ? 14 : 26,
                                  letterSpacing: isRetro ? 0.0 : -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: AppTypography.bodyText.copyWith(
                                color: AppColors.textPlaceholder,
                                fontSize: isRetro ? 11 : 12.5,
                              ),
                            ),
                          ],
                        );

                        final controlsGroup = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildProgressCapsule(
                              progress: progress,
                              doneTasks: doneTasks,
                              totalTasks: totalTasks,
                            ),
                            _RoutineButton(onReturn: _refreshToday),
                            const _SettingsGearButton(),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              greetingSection,
                              const SizedBox(height: 12),
                              controlsGroup,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: greetingSection),
                            const SizedBox(width: 12),
                            controlsGroup,
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 1. Quick Entry Wallet & Shield Cards ─────────────────────
                  const _StaggeredCard(
                    index: 1,
                    child: WalletSummaryCard(),
                  ),

                  const SizedBox(height: 20),

                  // ── 2. Tasks Section (Main Focus) ────────────────────────────
                  Showcase(
                    key: coachTaskList,
                    description:
                        'Your timeline of tasks. Tap any card to start, complete, or reschedule.',
                    descTextStyle: descStyle,
                    tooltipBackgroundColor: AppColors.cardHoverActive,
                    tooltipBorderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    targetBorderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(14),
                    targetPadding: const EdgeInsets.all(6),
                    overlayColor: _kOverlayColor,
                    overlayOpacity: _kOverlayOpacity,
                    movingAnimationDuration: _kMovingDuration,
                    scaleAnimationDuration: _kScaleDuration,
                    scaleAnimationCurve: Curves.easeOutCubic,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (activeTasks.isEmpty)
                          _StaggeredCard(
                            index: 3,
                            child: _EmptyTaskState(
                              hasTasks: totalTasks > 0,
                              allDone:
                                  totalTasks > 0 && doneTasks == totalTasks,
                              onRefresh: _refreshToday,
                            ),
                          )
                        else ...[
                          // 1. Scheduled Timeline
                          if (scheduledTasks.isNotEmpty) ...[
                            _StaggeredCard(
                              index: 3,
                              child: _buildTimelineHeader(
                                'SCHEDULED TIMELINE',
                                actionLabel: isRetro ? 'EDIT ROUTINE' : 'Edit Routine',
                                onAction: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RoutineBuilderScreen(),
                                    ),
                                  ).then((_) => _refreshToday());
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < scheduledTasks.length; i++) ...[
                              _buildTimeMarker(scheduledTasks[i]),
                              _StaggeredCard(
                                index: 3 + i,
                                child: TaskCard(
                                  key: ValueKey(scheduledTasks[i].id),
                                  task: scheduledTasks[i],
                                  onMarkDone: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .markTaskDone(scheduledTasks[i].id),
                                  onStart: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .startTask(scheduledTasks[i].id),
                                  onSkip: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .markTaskSkipped(scheduledTasks[i].id),
                                  onReschedule: (date) => ref
                                      .read(todayTasksProvider.notifier)
                                      .rescheduleTask(
                                        scheduledTasks[i].id,
                                        date,
                                      ),
                                  onDismissBuffer: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .dismissBuffer(scheduledTasks[i].id),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],

                          // 2. Flexible / Floating Section
                          if (flexibleTasks.isNotEmpty) ...[
                            _StaggeredCard(
                              index: 4,
                              child: _buildTimelineHeader('FLEXIBLE WINDOW'),
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < flexibleTasks.length; i++) ...[
                              _StaggeredCard(
                                index: 4 + i,
                                child: TaskCard(
                                  key: ValueKey(flexibleTasks[i].id),
                                  task: flexibleTasks[i],
                                  onMarkDone: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .markTaskDone(flexibleTasks[i].id),
                                  onStart: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .startTask(flexibleTasks[i].id),
                                  onSkip: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .markTaskSkipped(flexibleTasks[i].id),
                                  onReschedule: (date) => ref
                                      .read(todayTasksProvider.notifier)
                                      .rescheduleTask(
                                        flexibleTasks[i].id,
                                        date,
                                      ),
                                  onDismissBuffer: () => ref
                                      .read(todayTasksProvider.notifier)
                                      .dismissBuffer(flexibleTasks[i].id),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // ── 4. Quick-Add Button ───────────────────────────────────────
                  Showcase(
                    key: coachQuickAdd,
                    description:
                        'Tap here to add an ad-hoc or flexible task for today.',
                    descTextStyle: descStyle,
                    tooltipBackgroundColor: AppColors.cardHoverActive,
                    tooltipBorderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    targetBorderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(14),
                    targetPadding: const EdgeInsets.all(6),
                    overlayColor: _kOverlayColor,
                    overlayOpacity: _kOverlayOpacity,
                    movingAnimationDuration: _kMovingDuration,
                    scaleAnimationDuration: _kScaleDuration,
                    scaleAnimationCurve: Curves.easeOutCubic,
                    child: const _StaggeredCard(
                      index: 5,
                      child: QuickAddButton(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 5. Completed Tasks Toggle ─────────────────────────────────
                  _StaggeredCard(index: 6, child: _CompletedTasksToggle()),

                  // ── 6. Skipped Tasks Toggle ──────────────────────────────────
                  const _StaggeredCard(index: 7, child: _SkippedTasksToggle()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCapsule({
    required double progress,
    required int doneTasks,
    required int totalTasks,
  }) {
    final isRetro = AppColors.isRetro;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardBorder,
          width: isRetro ? 2.0 : 1.0,
        ),
        boxShadow: isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0.0,
                end: progress.clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, animatedProgress, _) {
                final isAllDone = animatedProgress >= 1.0 && totalTasks > 0;
                return Stack(
                  children: [
                    CircularProgressIndicator(
                      value: animatedProgress,
                      strokeWidth: 2.4,
                      backgroundColor: isRetro
                          ? AppColors.cardBorder.withValues(alpha: 0.2)
                          : (AppColors.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08)),
                      color: isAllDone
                          ? AppColors.successDone
                          : AppColors.accentPrimary,
                    ),
                    Center(
                      child: Text(
                        '$doneTasks',
                        style: AppTypography.scoreStat.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isAllDone
                              ? AppColors.successDone
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'of $totalTasks done',
            style: AppTypography.tagChip.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineHeader(
    String label, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isRetro = AppColors.isRetro;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTypography.sectionLabel.copyWith(
                fontSize: 11,
                letterSpacing: 1.0,
                color: AppColors.textPlaceholder,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: isRetro
                  ? AppColors.cardBorder.withValues(alpha: 0.3)
                  : (AppColors.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.dividerBorderHover),
              height: 1,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: isRetro
                        ? RetroTypography.overline.copyWith(
                            fontSize: 8.5,
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w700,
                          )
                        : AppTypography.tagChip.copyWith(
                            fontSize: 11,
                            color: AppColors.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: AppColors.accentPrimary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeMarker(DailyTaskInstance task) {
    if (task.scheduledTime == null || task.isBufferBlock) {
      return const SizedBox.shrink();
    }
    final timeFormatted = _formatTimeOfDay(task.scheduledTime!);
    final inProgress = task.status == TaskStatus.inProgress;
    final isRetro = AppColors.isRetro;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: inProgress ? 8 : 7,
            height: inProgress ? 8 : 7,
            decoration: BoxDecoration(
              shape: isRetro ? BoxShape.rectangle : BoxShape.circle,
              color: inProgress
                  ? AppColors.accentPrimary
                  : (isRetro
                      ? AppColors.textPlaceholder
                      : (AppColors.isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppColors.textPlaceholder.withValues(alpha: 0.6))),
              border: isRetro
                  ? Border.all(color: AppColors.cardBorder, width: 1.0)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeFormatted,
            style: AppTypography.cardTime.copyWith(
              fontSize: 11,
              color: inProgress
                  ? AppColors.accentPrimary
                  : AppColors.textPlaceholder,
              fontWeight: inProgress ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: inProgress
                  ? AppColors.accentPrimary.withValues(alpha: 0.25)
                  : (isRetro
                      ? AppColors.cardBorder.withValues(alpha: 0.2)
                      : (AppColors.isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : AppColors.dividerBorderHover)),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkippedTasksToggle extends ConsumerStatefulWidget {
  const _SkippedTasksToggle();

  @override
  ConsumerState<_SkippedTasksToggle> createState() =>
      _SkippedTasksToggleState();
}

class _SkippedTasksToggleState extends ConsumerState<_SkippedTasksToggle> {
  final Set<String> _restoring = {};

  @override
  Widget build(BuildContext context) {
    final skipped = ref.watch(skippedTasksProvider);
    if (skipped.isEmpty) return const SizedBox.shrink();
    final isRetro = AppColors.isRetro;

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: const PageStorageKey('skipped_tasks'),
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.textPlaceholder,
        collapsedIconColor: AppColors.textPlaceholder,
        title: Text(
          'Skipped (${skipped.length})',
          style: AppTypography.sectionLabel.copyWith(
            color: AppColors.textPlaceholder,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        children: skipped
            .map(
              (task) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withValues(
                    alpha: isRetro ? 0.7 : 0.6,
                  ),
                  borderRadius:
                      isRetro ? BorderRadius.zero : BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: isRetro ? 2.0 : 1.0,
                  ),
                  boxShadow: isRetro
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.warningTag.withValues(alpha: 0.12),
                            borderRadius: isRetro
                                ? BorderRadius.zero
                                : BorderRadius.circular(6),
                            border: isRetro
                                ? Border.all(
                                    color: AppColors.cardBorder,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Icon(
                            Icons.redo_rounded,
                            size: 14,
                            color: AppColors.warningTag,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.title,
                            style: AppTypography.cardTitle.copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.textMuted,
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Skipped',
                          style: AppTypography.tagChip.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        ActionButton(
                          icon: Icons.restore_rounded,
                          label: _restoring.contains(task.id)
                              ? 'Restoring...'
                              : 'Restore',
                          isLoading: _restoring.contains(task.id),
                          color: AppColors.accentPrimary,
                          onTap: _restoring.contains(task.id)
                              ? null
                              : () async {
                                  setState(() => _restoring.add(task.id));
                                  try {
                                    await ref
                                        .read(todayTasksProvider.notifier)
                                        .restoreTask(task.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not restore task. Please retry.',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _restoring.remove(task.id));
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Animated Staggered Card Entry ────────────────────────────────────────────

class _StaggeredCard extends StatelessWidget {
  final Widget child;
  final int index;

  const _StaggeredCard({required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    // Shared entrance: replays with the shell's tab-entrance controller on
    // every main-tab switch, one-shot when mounted outside the shell.
    return StaggeredCard(index: index, child: child);
  }
}

// ─── Routine Builder Button with Tactile Feedback ─────────────────────────────

class _RoutineButton extends StatefulWidget {
  final VoidCallback? onReturn;
  const _RoutineButton({this.onReturn});

  @override
  State<_RoutineButton> createState() => _RoutineButtonState();
}

class _RoutineButtonState extends State<_RoutineButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    return Semantics(
      button: true,
      label: 'Routine Builder',
      child: Tooltip(
        message: 'Routine Builder',
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
            ).then((_) => widget.onReturn?.call());
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius:
                    isRetro ? BorderRadius.zero : BorderRadius.circular(12),
                border: Border.all(
                  color: _isPressed
                      ? AppColors.accentPrimary
                      : AppColors.cardBorder,
                  width: isRetro ? 2.0 : 1.0,
                ),
                boxShadow: isRetro && !_isPressed
                    ? [
                        BoxShadow(
                          color: AppColors.retroShadowColor,
                          offset: const Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.calendar_view_week_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Settings Gear Button with Tactile Feedback ───────────────────────────────

class _SettingsGearButton extends StatefulWidget {
  const _SettingsGearButton();

  @override
  State<_SettingsGearButton> createState() => _SettingsGearButtonState();
}

class _SettingsGearButtonState extends State<_SettingsGearButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    return Semantics(
      button: true,
      label: 'Settings',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius:
                  isRetro ? BorderRadius.zero : BorderRadius.circular(12),
              border: Border.all(
                color: _isPressed
                    ? AppColors.accentPrimary
                    : AppColors.cardBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro && !_isPressed
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Empty State ─────────────────────────────────────────────────────

class _EmptyTaskState extends StatelessWidget {
  final bool hasTasks;
  final bool allDone;
  final VoidCallback? onRefresh;
  const _EmptyTaskState({
    required this.hasTasks,
    required this.allDone,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final emptyIcon = allDone
        ? Icons.check_rounded
        : hasTasks
            ? Icons.hourglass_empty_rounded
            : Icons.calendar_view_week_rounded;
    final emptyColor = allDone
        ? AppColors.successDone
        : hasTasks
            ? AppColors.warningTag
            : AppColors.accentPrimary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (context, val, _) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius:
                isRetro ? BorderRadius.zero : BorderRadius.circular(16),
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
                      color: Colors.black.withValues(
                        alpha: AppColors.isDark ? 0.14 : 0.05,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Transform.scale(
                scale: val.clamp(0.0, 1.0),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: isRetro ? BoxShape.rectangle : BoxShape.circle,
                    color: emptyColor.withValues(alpha: 0.12),
                    border: isRetro
                        ? Border.all(color: emptyColor, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: emptyColor.withValues(
                          alpha: 0.12 * val,
                        ),
                        blurRadius: isRetro ? 0 : 8,
                        offset: isRetro
                            ? const Offset(2, 2)
                            : Offset.zero,
                      ),
                    ],
                  ),
                  child: Icon(
                    emptyIcon,
                    color: emptyColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Text(
                  allDone
                      ? (isRetro ? 'ALL TASKS DONE!' : 'All tasks completed!')
                      : hasTasks
                          ? (isRetro ? 'NO ACTIVE TASKS' : 'No active tasks')
                          : (isRetro ? 'NO TASKS FOR TODAY' : 'Make room for your day'),
                  textAlign: TextAlign.center,
                  style: isRetro
                      ? RetroTypography.displayHeading.copyWith(
                          fontSize: 13,
                        )
                      : AppTypography.cardTitle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Text(
                  allDone
                      ? 'Your planned tasks are done. Review your day whenever you are ready.'
                      : hasTasks
                          ? 'Restore a skipped task below or add something new.'
                          : 'Set up your recurring schedule to automatically plan your days.',
                  textAlign: TextAlign.center,
                  style: isRetro
                      ? RetroTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        )
                      : AppTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                ),
              ),
              if (!hasTasks) ...[
                const SizedBox(height: 18),
                _OpenRoutineButton(
                  isRetro: isRetro,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoutineBuilderScreen(),
                      ),
                    ).then((_) => onRefresh?.call());
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OpenRoutineButton extends StatefulWidget {
  final bool isRetro;
  final VoidCallback onTap;

  const _OpenRoutineButton({
    required this.isRetro,
    required this.onTap,
  });

  @override
  State<_OpenRoutineButton> createState() => _OpenRoutineButtonState();
}

class _OpenRoutineButtonState extends State<_OpenRoutineButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isRetro = widget.isRetro;
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary,
            borderRadius:
                isRetro ? BorderRadius.zero : BorderRadius.circular(12),
            border: Border.all(
              color: isRetro ? AppColors.cardBorder : Colors.transparent,
              width: isRetro ? 2.0 : 0.0,
            ),
            boxShadow: isRetro && !_isPressed
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.accentPrimary.withValues(
                        alpha: 0.25,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_view_week_rounded,
                size: 17,
                color: isRetro && !isDark
                    ? AppColors.textPrimary
                    : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                isRetro ? 'OPEN ROUTINE BUILDER' : 'Open Routine Builder',
                style: isRetro
                    ? RetroTypography.buttonLabel.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF141418)
                            : AppColors.textPrimary,
                      )
                    : AppTypography.buttonLabel.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Completed Tasks Collapsible Toggle ───────────────────────────────────────

class _CompletedTasksToggle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CompletedTasksToggle> createState() =>
      _CompletedTasksToggleState();
}

class _CompletedTasksToggleState extends ConsumerState<_CompletedTasksToggle> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(completedTasksProvider);
    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textPlaceholder,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'COMPLETED - ${completed.length} ${completed.length == 1 ? 'task' : 'tasks'}',
                    style: AppTypography.sectionLabel.copyWith(
                      color: AppColors.textPlaceholder,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  children: [
                    const SizedBox(height: 4),
                    ...completed.map(
                      (task) => TaskCard(
                        key: ValueKey('done_${task.id}'),
                        task: task,
                        onMarkDone: () {},
                        onSkip: () {},
                        onReschedule: (_) {},
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
