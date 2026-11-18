import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../providers/theme_provider.dart';
import '../providers/review_providers.dart';
import 'dashboard/dashboard_screen.dart';
import 'wallet/wallet_screen.dart';
import 'insights/insights_screen.dart';
import '../services/month_rollover_service.dart';
import '../services/notification_service.dart';
import '../providers/dashboard_providers.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetClicks;
  bool _refreshing = false;
  DateTime? _lastRefreshDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _initializeHomeWidget();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshLiveState();
    });
  }

  Future<void> _initializeHomeWidget() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (!mounted) return;
      _widgetClicks = HomeWidget.widgetClicked.listen(
        _handleWidgetClick,
        onError: (Object error) =>
            debugPrint('Widget click unavailable: $error'),
      );
      if (uri != null) _handleWidgetClick(uri);
    } on MissingPluginException catch (error) {
      debugPrint('Home widget unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint('Home widget unavailable: $error');
    }
  }

  Future<void> _refreshLiveState() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      final now = DateUtils.dateOnly(DateTime.now());
      if (_lastRefreshDate != now) {
        await MonthRolloverService().checkAndRollover();
        _lastRefreshDate = now;
      }
      if (mounted) await ref.read(todayTasksProvider.notifier).loadTodayTasks();
    } catch (error) {
      debugPrint('Live task refresh failed: $error');
    } finally {
      _refreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(localTimeProvider);
      _refreshLiveState();
      NotificationService().scheduleEODPrompt().catchError((Object error) {
        debugPrint('Reminder refresh failed: $error');
        return false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    super.dispose();
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri != null && uri.host == 'reschedule') {
      final taskId = uri.queryParameters['taskId'];
      if (taskId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now.add(const Duration(days: 1)),
            firstDate: now.add(const Duration(days: 1)),
            lastDate: now.add(const Duration(days: 30)),
            helpText: 'RESCHEDULE TASK',
          );
          if (picked != null && mounted) {
            try {
              await ref
                  .read(todayTasksProvider.notifier)
                  .rescheduleTask(taskId, picked);
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not reschedule the task. Please try again.',
                  ),
                ),
              );
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme so this widget rebuilds whenever the theme changes.
    // Each screen gets a ValueKey tied to the active theme name so that
    // Flutter discards the old State and creates a fresh one — instantly
    // reflecting the new AppColors / AppTypography without needing a restart.
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(localTimeProvider, (_, next) {
      if (next.hasValue) _refreshLiveState();
    });
    final now = ref.watch(localTimeProvider).valueOrNull ?? DateTime.now();
    final hasTodayLog = ref.watch(todayReviewProvider) != null;
    final showEodBadge = !hasTodayLog && now.hour >= 21;

    final screens = [
      DashboardScreen(key: ValueKey('dashboard_${themeMode.name}')),
      WalletScreen(key: ValueKey('wallet_${themeMode.name}')),
      InsightsScreen(key: ValueKey('insights_${themeMode.name}')),
    ];

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: IndexedStack(index: _currentIndex, children: screens),
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

  const _MomentumNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.showEodBadge,
  });

  static const _items = [
    (
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Today',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
    ),
    (
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Insights',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(
            color: isRetro
                ? AppColors.cardBorder
                : AppColors.dividerBorderHover,
            width: isRetro ? 2.0 : 1.0,
          ),
        ),
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
            child: Semantics(
              button: true,
              selected: active,
              label: item.label,
              hint: i == 2 && showEodBadge ? 'Day review available' : null,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated pill indicator
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          height: isRetro ? 3.5 : 3.0,
                          width: active ? (isRetro ? 24.0 : 20.0) : 0.0,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary,
                            borderRadius: isRetro
                                ? BorderRadius.zero
                                : BorderRadius.circular(2),
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              active ? item.activeIcon : item.icon,
                              color: active
                                  ? AppColors.accentPrimary
                                  : AppColors.textPlaceholder,
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
                                    shape: isRetro
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                    color: AppColors.warningTag,
                                    border: isRetro
                                        ? Border.all(
                                            color: AppColors.cardBorder,
                                            width: 1.0,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: AppTypography.navLabel.copyWith(
                            color: active
                                ? AppColors.accentPrimary
                                : AppColors.textPlaceholder,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
