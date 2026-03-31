import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/task_card.dart';
import '../../providers/dashboard_providers.dart';
import '../../widgets/wallet_summary_card.dart';
import '../../widgets/monthly_focus_section.dart';
import '../../models/user_settings.dart';
import '../../models/routine_period.dart';
import '../../constants/avatar_icons.dart';
import '../profile/profile_screen.dart';
import 'package:hive/hive.dart';
import 'quick_add_button.dart';
import '../../services/notification_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onForegroundAction = () {
      ref.read(todayTasksProvider.notifier).loadTodayTasks();
    };
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

  String _periodLabel() {
    final now = DateTime.now();
    final monthName = const [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ][now.month - 1];
    final box = Hive.box<RoutinePeriod>('routinePeriods');
    final period = box.values.cast<RoutinePeriod?>().firstWhere(
      (p) => p!.isActive,
      orElse: () => null,
    );
    if (period == null) return monthName.toUpperCase();
    final weekNum = (now.difference(period.startDate).inDays / 7).floor() + 1;
    return 'WEEK $weekNum · ${monthName.toUpperCase()}';
  }

  String _timeBlockLabel() {
    final h = DateTime.now().hour;
    if (h < 12) return 'MORNING BLOCK';
    if (h < 17) return 'AFTERNOON BLOCK';
    return 'EVENING BLOCK';
  }

  @override
  Widget build(BuildContext context) {
    final progressLabel = ref.watch(progressProvider);
    final progressFraction = ref.watch(progressFractionProvider);
    final scoreMap = ref.watch(liveDayScoreProvider);
    final score = scoreMap['score'] as double;
    final grade = scoreMap['grade'] as String;
    final activeTasks = ref.watch(activeTasksProvider);
    final settings = Hive.box<UserSettings>('userSettings').get('user') ?? UserSettings();
    final firstName = settings.firstName.isEmpty ? 'there' : settings.firstName;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _periodLabel(),
                    style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.4)),
                      ),
                      child: Icon(kAvatarIcons[settings.avatarIndex], color: AppColors.accentPrimary, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  text: '${_greeting()}\n',
                  style: AppTypography.displayHeading,
                  children: [
                    TextSpan(
                      text: firstName,
                      style: AppTypography.displayHeading.copyWith(color: AppColors.accentPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161619),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E1E26)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 3,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E26),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: progressFraction),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, __) => FractionallySizedBox(
                              widthFactor: value,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.accentPrimary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Text(progressLabel, style: AppTypography.bodyText.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161619),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E1E26)),
                    ),
                    child: Text(
                      'Score $grade · ${score.toStringAsFixed(0)}%',
                      style: AppTypography.scoreStat.copyWith(color: AppColors.accentPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              const WalletSummaryCard(),

              // ── Section divider ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(child: Container(height: 1, color: const Color(0xFF141418))),
                  ],
                ),
              ),

              const MonthlyFocusSection(),

              // ── Section divider ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Container(height: 1, color: const Color(0xFF141418))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'NOW · ${_timeBlockLabel()}',
                        style: AppTypography.sectionLabel.copyWith(
                          color: const Color(0xFF333340),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: const Color(0xFF141418))),
                  ],
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (activeTasks.isEmpty)
                      _EmptyTaskState()
                    else
                      ...activeTasks.map((task) => TaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        onMarkDone: () => ref.read(todayTasksProvider.notifier).markTaskDone(task.id),
                        onSkip: () => ref.read(todayTasksProvider.notifier).markTaskSkipped(task.id),
                        onReschedule: (date) => ref.read(todayTasksProvider.notifier).rescheduleTask(task.id, date),
                        onDismissBuffer: () => ref.read(todayTasksProvider.notifier).dismissBuffer(task.id),
                      )),
                  ],
                ),
              ),

              _CompletedTasksToggle(),



              const QuickAddButton(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.textPlaceholder, size: 32),
          const SizedBox(height: 10),
          Text('No tasks scheduled', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text('Tap + below to add one', style: AppTypography.sectionLabel),
        ],
      ),
    );
  }
}

class _CompletedTasksToggle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CompletedTasksToggle> createState() => _CompletedTasksToggleState();
}

class _CompletedTasksToggleState extends ConsumerState<_CompletedTasksToggle> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(completedTasksProvider).where((t) => !t.isBufferBlock).toList();
    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F13),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1A1A24)),
            ),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'COMPLETED — ${completed.length} ${completed.length == 1 ? 'task' : 'tasks'}',
                  style: AppTypography.sectionLabel.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  children: [
                    const SizedBox(height: 4),
                    ...completed.map((task) => TaskCard(
                          key: ValueKey('done_${task.id}'),
                          task: task,
                          onMarkDone: () {},
                          onSkip: () {},
                          onReschedule: (_) {},
                        )),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
