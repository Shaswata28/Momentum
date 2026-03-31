import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dashboard/dashboard_screen.dart';
import 'wallet/wallet_screen.dart';
import 'insights/insights_screen.dart';

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

  @override
  void initState() {
    super.initState();
    HomeWidget.widgetClicked.listen((Uri? uri) => _handleWidgetClick(uri));
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
       if (uri != null) _handleWidgetClick(uri);
    });
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri != null && uri.host == 'reschedule') {
      final taskId = uri.queryParameters['taskId'];
      if (taskId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
              showModalBottomSheet(
                 context: context,
                 backgroundColor: AppColors.appBackground,
                 builder: (context) => Container(
                     padding: const EdgeInsets.all(24),
                     height: 300,
                     child: Center(
                         child: Text('Reschedule flow for Task $taskId', style: AppTypography.displayHeading),
                     )
                 )
              );
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _MomentumNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─── Custom nav bar with animated pill indicator ──────────────────────────────

class _MomentumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MomentumNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.dashboard_outlined,          activeIcon: Icons.dashboard,                   label: 'Today'),
    (icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet,  label: 'Wallet'),
    (icon: Icons.insights_outlined,           activeIcon: Icons.insights,                    label: 'Insights'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        border: Border(top: BorderSide(color: Color(0xFF141418), width: 1)),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final active = currentIndex == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated pill indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: 3,
                    width: active ? 24 : 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Icon(
                    active ? item.activeIcon : item.icon,
                    color: active ? AppColors.accentPrimary : const Color(0xFF3A3A50),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: AppTypography.navLabel.copyWith(
                      color: active ? AppColors.accentPrimary : const Color(0xFF3A3A50),
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
