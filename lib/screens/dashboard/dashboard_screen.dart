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
import 'package:hive/hive.dart';
import 'quick_add_button.dart';
import '../../services/notification_service.dart';

final GlobalKey coachTaskList = GlobalKey();
final GlobalKey coachQuickAdd = GlobalKey();

final _kTooltipBg = AppColors.cardHoverActive;
const _kOverlayColor = Color(0xFF000000);
const _kOverlayOpacity = 0.82;
const _kMovingDuration = Duration(milliseconds: 300);
const _kScaleDuration = Duration(milliseconds: 180);
final _kDescStyle = AppTypography.bodyText.copyWith(
  color: AppColors.textSecondary,
  fontSize: 13,
  height: 1.45,
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  BuildContext? _showcaseCtx;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Refresh when a foreground notification action completes
    NotificationService.onForegroundAction = () {
      if (mounted) {
        ref.read(todayTasksProvider.notifier).loadTodayTasks();
      }
    };

    final userSettings = Hive.box<UserSettings>('userSettings').get('user');
    if (userSettings?.hasSeenCoachMarks ?? false) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _showcaseCtx == null) return;
        ShowCaseWidget.of(_showcaseCtx!).startShowCase([coachTaskList, coachQuickAdd]);
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
    NotificationService.onForegroundAction = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayTasksProvider.notifier).loadTodayTasks();
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
    final allTasks = ref.watch(todayTasksProvider);
    final activeTasks = ref.watch(activeTasksProvider);
    final completed = ref.watch(completedTasksProvider);

    final totalTasks = allTasks.where((t) => !t.isBufferBlock).length;
    final doneTasks = completed.length;
    final progress = totalTasks > 0 ? (doneTasks / totalTasks) : 0.0;

    final userSettings = Hive.box<UserSettings>('userSettings').get('user');
    final userName = (userSettings?.firstName.isNotEmpty ?? false) ? userSettings!.firstName : 'Friend';

    final now = DateTime.now();
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
                ref.read(todayTasksProvider.notifier).loadTodayTasks();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                children: [
                  // ── 0. Header: Greeting + Progress Ring + Settings Gear ────────
                  _StaggeredCard(
                    index: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _greeting(),
                                style: AppTypography.sectionLabel.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userName,
                                style: AppTypography.displayHeading.copyWith(
                                  fontSize: 26,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                style: AppTypography.bodyText.copyWith(
                                  color: AppColors.textPlaceholder,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Controls Group (Animated Progress Ring Capsule & Settings Gear)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: progress.clamp(0.0, 1.0)),
                                      duration: const Duration(milliseconds: 650),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, animatedProgress, _) {
                                        final isAllDone = animatedProgress >= 1.0 && totalTasks > 0;
                                        return Stack(
                                          children: [
                                            CircularProgressIndicator(
                                              value: animatedProgress,
                                              strokeWidth: 2.4,
                                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                                              color: isAllDone ? AppColors.successDone : AppColors.accentPrimary,
                                            ),
                                            Center(
                                              child: Text(
                                                '$doneTasks',
                                                style: AppTypography.scoreStat.copyWith(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isAllDone ? AppColors.successDone : AppColors.textPrimary,
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
                            ),
                            const SizedBox(width: 8),
                            const _SettingsGearButton(),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 1. Quick Entry Wallet Card ───────────────────────────────
                  const _StaggeredCard(
                    index: 1,
                    child: WalletSummaryCard(),
                  ),

                  const SizedBox(height: 20),

                  // ── 2. Tasks Section (Main Focus) ────────────────────────────
                  Showcase(
                    key: coachTaskList,
                    description: 'Your timeline of tasks. Tap any card to start, complete, or reschedule.',
                    descTextStyle: _kDescStyle,
                    tooltipBackgroundColor: _kTooltipBg,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    targetBorderRadius: BorderRadius.circular(14),
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
                            index: 2,
                            child: _EmptyTaskState(),
                          )
                        else ...[
                          // 1. Scheduled Timeline
                          if (scheduledTasks.isNotEmpty) ...[
                            _StaggeredCard(
                              index: 2,
                              child: _buildTimelineHeader('SCHEDULED TIMELINE'),
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < scheduledTasks.length; i++) ...[
                              _buildTimeMarker(scheduledTasks[i]),
                              _StaggeredCard(
                                index: 2 + i,
                                child: TaskCard(
                                  key: ValueKey(scheduledTasks[i].id),
                                  task: scheduledTasks[i],
                                  onMarkDone: () => ref.read(todayTasksProvider.notifier).markTaskDone(scheduledTasks[i].id),
                                  onStart: () => ref.read(todayTasksProvider.notifier).startTask(scheduledTasks[i].id),
                                  onSkip: () => ref.read(todayTasksProvider.notifier).markTaskSkipped(scheduledTasks[i].id),
                                  onReschedule: (date) => ref.read(todayTasksProvider.notifier).rescheduleTask(scheduledTasks[i].id, date),
                                  onDismissBuffer: () => ref.read(todayTasksProvider.notifier).dismissBuffer(scheduledTasks[i].id),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],

                          // 2. Flexible / Floating Section
                          if (flexibleTasks.isNotEmpty) ...[
                            _StaggeredCard(
                              index: 3,
                              child: _buildTimelineHeader('FLEXIBLE WINDOW'),
                            ),
                            const SizedBox(height: 8),
                            for (int i = 0; i < flexibleTasks.length; i++) ...[
                              _StaggeredCard(
                                index: 3 + i,
                                child: TaskCard(
                                  key: ValueKey(flexibleTasks[i].id),
                                  task: flexibleTasks[i],
                                  onMarkDone: () => ref.read(todayTasksProvider.notifier).markTaskDone(flexibleTasks[i].id),
                                  onStart: () => ref.read(todayTasksProvider.notifier).startTask(flexibleTasks[i].id),
                                  onSkip: () => ref.read(todayTasksProvider.notifier).markTaskSkipped(flexibleTasks[i].id),
                                  onReschedule: (date) => ref.read(todayTasksProvider.notifier).rescheduleTask(flexibleTasks[i].id, date),
                                  onDismissBuffer: () => ref.read(todayTasksProvider.notifier).dismissBuffer(flexibleTasks[i].id),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // ── 3. Quick-Add Button ───────────────────────────────────────
                  Showcase(
                    key: coachQuickAdd,
                    description: 'Tap here to add an ad-hoc or flexible task for today.',
                    descTextStyle: _kDescStyle,
                    tooltipBackgroundColor: _kTooltipBg,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    targetBorderRadius: BorderRadius.circular(14),
                    targetPadding: const EdgeInsets.all(6),
                    overlayColor: _kOverlayColor,
                    overlayOpacity: _kOverlayOpacity,
                    movingAnimationDuration: _kMovingDuration,
                    scaleAnimationDuration: _kScaleDuration,
                    scaleAnimationCurve: Curves.easeOutCubic,
                    child: const _StaggeredCard(
                      index: 4,
                      child: QuickAddButton(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 4. Completed Tasks Toggle ─────────────────────────────────
                  _StaggeredCard(
                    index: 5,
                    child: _CompletedTasksToggle(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.sectionLabel.copyWith(
              fontSize: 11,
              letterSpacing: 1.0,
              color: AppColors.textPlaceholder,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Colors.white.withValues(alpha: 0.05),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeMarker(DailyTaskInstance task) {
    if (task.scheduledTime == null || task.isBufferBlock) return const SizedBox.shrink();
    final timeFormatted = _formatTimeOfDay(task.scheduledTime!);
    final inProgress = task.status == TaskStatus.inProgress;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: inProgress ? 8 : 7,
            height: inProgress ? 8 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: inProgress ? AppColors.accentPrimary : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeFormatted,
            style: AppTypography.cardTime.copyWith(
              fontSize: 11,
              color: inProgress ? AppColors.accentPrimary : AppColors.textPlaceholder,
              fontWeight: inProgress ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: inProgress
                  ? AppColors.accentPrimary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.04),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Staggered Card Entry ────────────────────────────────────────────

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
            offset: Offset(0, 18 * (1.0 - value)),
            child: child,
          ),
        );
      },
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
    return GestureDetector(
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Animated Empty State ─────────────────────────────────────────────────────

class _EmptyTaskState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (context, val, _) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Transform.scale(
                scale: val.clamp(0.0, 1.0),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.successDone.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successDone.withValues(alpha: 0.25 * val),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Icon(Icons.check_rounded, color: AppColors.successDone, size: 26),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Text(
                  'All clear for today!',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: Text(
                  'No active tasks scheduled right now. Tap below to add a task.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Completed Tasks Collapsible Toggle ───────────────────────────────────────

class _CompletedTasksToggle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CompletedTasksToggle> createState() => _CompletedTasksToggleState();
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
                Text(
                  'COMPLETED — ${completed.length} ${completed.length == 1 ? 'task' : 'tasks'}',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 11,
                    letterSpacing: 0.8,
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
