import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dashboard/dashboard_screen.dart';
import 'wallet/wallet_screen.dart';
import 'insights/insights_screen.dart';
import '../repositories/eod_log_repository.dart';
import '../repositories/daily_task_instance_repository.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';
import '../providers/dashboard_providers.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const WalletScreen(),
    const InsightsScreen(),
  ];

  Timer? _liveTaskTimer;

  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => _handleWidgetClick(uri));
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
       if (uri != null) _handleWidgetClick(uri);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService().requestPermissions();
      NotificationService.onForegroundAction = () {
        ref.read(todayTasksProvider.notifier).loadTodayTasks();
      };
    });

    _syncLiveTask();
    _liveTaskTimer = Timer.periodic(const Duration(minutes: 1), (_) => _syncLiveTask());
  }

  void _syncLiveTask() {
    final repo = DailyTaskInstanceRepository();
    final tasks = repo.getTasksForDate(DateTime.now());
    WidgetService.syncWidgetState(tasks);
  }

  @override
  void dispose() {
    _liveTaskTimer?.cancel();
    super.dispose();
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri != null && uri.host == 'reschedule') {
      final taskId = uri.queryParameters['taskId'];
      if (taskId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now.add(const Duration(days: 1)),
            firstDate: now.add(const Duration(days: 1)),
            lastDate: now.add(const Duration(days: 30)),
            helpText: 'RESCHEDULE TASK',
          );
          if (picked != null && mounted) {
            ref.read(todayTasksProvider.notifier).rescheduleTask(taskId, picked);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final repo = EODLogRepository();
    final hasTodayLog = repo.getAllLogs().any((l) =>
        l.date.year == now.year &&
        l.date.month == now.month &&
        l.date.day == now.day);
    final showEodBadge = !hasTodayLog && now.hour >= 21;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _MomentumNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        showEodBadge: showEodBadge,
      ),
    );
  }
}

// ─── Custom nav bar with animated pill indicator ──────────────────────────────

class _MomentumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showEodBadge;

  const _MomentumNavBar({required this.currentIndex, required this.onTap, required this.showEodBadge});

  static const _items = [
    (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard_rounded,          label: 'Today'),
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
    (icon: Icons.insights_outlined,           activeIcon: Icons.insights_rounded,           label: 'Insights'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.appBackground,
        border: Border(top: BorderSide(color: AppColors.dividerBorderHover, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final active = currentIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(i);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pill indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    height: 3,
                    width: active ? 20 : 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        color: active ? AppColors.accentPrimary : AppColors.textPlaceholder,
                        size: 22,
                      ),
                      if (i == 2 && showEodBadge)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.warningTag,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: AppTypography.navLabel.copyWith(
                      color: active ? AppColors.accentPrimary : AppColors.textPlaceholder,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
