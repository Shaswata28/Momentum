import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../providers/wallet_providers.dart';
import '../../models/transaction.dart';
import '../../models/wallet_settings.dart';
import 'widgets/transaction_row.dart';
import 'widgets/monthly_summary_card.dart';
import 'widgets/budget_bar.dart';
import 'widgets/savings_goal_card.dart';
import 'widgets/fixed_bills_section.dart';
import 'transaction_sheet.dart';
import 'wallet_settings_sheet.dart';
import '../../widgets/action_button.dart';
import '../../widgets/staggered_card.dart';

enum _WalletTab {
  transactions,
  goals,
  bills;

  String get label {
    switch (this) {
      case _WalletTab.transactions:
        return 'TRANSACTIONS';
      case _WalletTab.goals:
        return 'GOALS';
      case _WalletTab.bills:
        return 'BILLS';
    }
  }
}

enum _TxFilter { all, income, expense, borrowed, lent, unsettled }

extension _TxFilterLabel on _TxFilter {
  String get label {
    switch (this) {
      case _TxFilter.all:
        return 'All';
      case _TxFilter.income:
        return 'Income';
      case _TxFilter.expense:
        return 'Expense';
      case _TxFilter.borrowed:
        return 'Borrowed';
      case _TxFilter.lent:
        return 'Lent';
      case _TxFilter.unsettled:
        return 'Unsettled';
    }
  }

  Color get color {
    switch (this) {
      case _TxFilter.all:
        return AppColors.accentPrimary;
      case _TxFilter.income:
        return AppColors.successDone;
      case _TxFilter.expense:
        return AppColors.errorAlert;
      case _TxFilter.borrowed:
        return AppColors.errorAlert;
      case _TxFilter.lent:
        return AppColors.accentPrimary;
      case _TxFilter.unsettled:
        return AppColors.warningTag;
    }
  }
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _TxFilter _filter = _TxFilter.all;
  _WalletTab _selectedTab = _WalletTab.transactions;

  void _showAddSheet(bool isIncome) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: AppColors.isRetro
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      builder: (_) => TransactionSheet(
        initialIsIncome: isIncome,
        visibleMonthId: ref.read(selectedMonthIdProvider),
      ),
    );
  }

  void _showIouSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: AppColors.isRetro
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      builder: (_) => TransactionSheet(
        initialIsIncome: false,
        startAsBorrowLend: true,
        visibleMonthId: ref.read(selectedMonthIdProvider),
      ),
    );
  }

  void _openMonthPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    final selectedDate = ref.read(selectedMonthDateProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: AppColors.isRetro
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      builder: (_) => _MonthPickerSheet(
        initialDate: selectedDate,
        onSelected: (newDate) {
          ref.read(selectedMonthDateProvider.notifier).state = newDate;
        },
      ),
    );
  }

  List<Transaction> _applyFilter(List<Transaction> txs) {
    switch (_filter) {
      case _TxFilter.all:
        return txs;
      case _TxFilter.income:
        return txs
            .where(
              (t) =>
                  t.direction == Direction.income &&
                  t.expenseType != ExpenseType.borrowed,
            )
            .toList();
      case _TxFilter.expense:
        return txs
            .where(
              (t) =>
                  t.direction == Direction.expense &&
                  t.expenseType != ExpenseType.lent &&
                  t.expenseType != ExpenseType.borrowed,
            )
            .toList();
      case _TxFilter.borrowed:
        return txs.where((t) => t.expenseType == ExpenseType.borrowed).toList();
      case _TxFilter.lent:
        return txs.where((t) => t.expenseType == ExpenseType.lent).toList();
      case _TxFilter.unsettled:
        return txs
            .where(
              (t) =>
                  !t.isSettled &&
                  (t.expenseType == ExpenseType.borrowed ||
                      t.expenseType == ExpenseType.lent),
            )
            .toList();
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);

    if (check == today) {
      return 'Today · ${DateFormat('MMM d').format(date)}';
    } else if (check == yesterday) {
      return 'Yesterday · ${DateFormat('MMM d').format(date)}';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedMonthDateProvider);
    final txs = ref.watch(selectedTransactionsProvider);
    final totals = ref.watch(selectedMonthlyTotalsProvider);
    final filtered = _applyFilter(txs);

    final monthFullLabel = DateFormat('MMMM yyyy').format(selectedDate);
    final monthShortLabel = DateFormat('MMM yyyy').format(selectedDate);

    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings = settingsBox.isEmpty
        ? WalletSettings()
        : settingsBox.getAt(0)!;

    final unsettledCount = txs
        .where(
          (t) =>
              !t.isSettled &&
              (t.expenseType == ExpenseType.borrowed ||
                  t.expenseType == ExpenseType.lent),
        )
        .length;

    // Group filtered transactions by date string
    final groupedTxs = <String, List<Transaction>>{};
    for (final tx in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      groupedTxs.putIfAbsent(key, () => []).add(tx);
    }

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: CustomScrollView(
            key: ValueKey(
              'wallet_scroll_${selectedDate.year}_${selectedDate.month}',
            ),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── 1. Heading + Control Cluster (Month Pill & Settings) ───────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Heading
                      Expanded(
                        child: Text(
                          'Wallet',
                          style: AppTypography.displayHeading.copyWith(
                            fontSize: AppColors.isRetro ? 14 : 26,
                            letterSpacing: AppColors.isRetro ? 0.0 : -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Controls on Right (Month Picker Pill & Settings Button)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _openMonthPicker(context),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: AppColors.isRetro
                                    ? BorderRadius.zero
                                    : BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                  width: AppColors.isRetro ? 2.0 : 1.0,
                                ),
                                boxShadow: AppColors.isRetro
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
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 14,
                                    color: AppColors.accentPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    monthShortLabel,
                                    style: AppTypography.tagChip.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: AppColors.textPlaceholder,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                shape: AppColors.isRetro
                                    ? const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      )
                                    : null,
                                builder: (_) => const WalletSettingsSheet(),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: AppColors.isRetro
                                    ? BorderRadius.zero
                                    : BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                  width: AppColors.isRetro ? 2.0 : 1.0,
                                ),
                                boxShadow: AppColors.isRetro
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
                                Icons.tune_rounded,
                                semanticLabel: 'Wallet settings',
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 2. Animated Main Content Body ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card 0: Monthly Summary Card
                      const _StaggeredCard(
                        index: 0,
                        child: MonthlySummaryCard(),
                      ),

                      const SizedBox(height: 14),

                      // Card 1: Quick Action Buttons (Income / Expense / IOU)
                      _StaggeredCard(
                        index: 1,
                        child: Row(
                          children: [
                            Expanded(
                              child: ActionButton(
                                icon: Icons.arrow_downward_rounded,
                                label: 'Income',
                                color: AppColors.successDone,
                                onTap: () => _showAddSheet(true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ActionButton(
                                icon: Icons.arrow_upward_rounded,
                                label: 'Expense',
                                color: AppColors.errorAlert,
                                onTap: () => _showAddSheet(false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ActionButton(
                                icon: Icons.swap_horiz_rounded,
                                label: 'IOU',
                                color: AppColors.accentPrimary,
                                onTap: _showIouSheet,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Card 2: Budget Progress Bar
                      if (settings.monthlyBudget > 0) ...[
                        const SizedBox(height: 14),
                        _StaggeredCard(
                          index: 2,
                          child: BudgetBar(
                            spent: totals.totalExpense,
                            limit: settings.monthlyBudget,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // ── Tab Bar (BILLS | GOALS | TRANSACTIONS) ───────────
                      _StaggeredCard(
                        index: 3,
                        child: _WalletTabBar(
                          selectedTab: _selectedTab,
                          onTabChanged: (tab) =>
                              setState(() => _selectedTab = tab),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Active Tab Content ────────────────────────────────
                      if (_selectedTab == _WalletTab.transactions) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'FILTER BY',
                                    style: AppTypography.sectionLabel.copyWith(
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                      color: AppColors.textPlaceholder,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '${filtered.length} total',
                                  style: AppTypography.tagChip.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textPlaceholder,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: _TxFilter.values.map((f) {
                                  final active = _filter == f;
                                  final isUnsettled = f == _TxFilter.unsettled;
                                  final isRetro = AppColors.isRetro;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _filter = f);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: active
                                              ? f.color.withValues(
                                                  alpha: AppColors.isDark
                                                      ? (isRetro ? 0.28 : 0.20)
                                                      : 0.14,
                                                )
                                              : AppColors.cardBackground,
                                          borderRadius: isRetro
                                              ? BorderRadius.zero
                                              : BorderRadius.circular(14),
                                          border: Border.all(
                                            color: active
                                                ? (isRetro
                                                      ? f.color
                                                      : f.color.withValues(
                                                          alpha: 0.6,
                                                        ))
                                                : (isRetro
                                                      ? AppColors.cardBorder
                                                      : Colors.white.withValues(
                                                          alpha: 0.06,
                                                        )),
                                            width: isRetro ? 1.5 : 1.0,
                                          ),
                                          boxShadow: (isRetro && active)
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .retroShadowColor,
                                                    offset: const Offset(2, 2),
                                                    blurRadius: 0,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              f.label,
                                              style: AppTypography.tagChip
                                                  .copyWith(
                                                    fontSize: 11.5,
                                                    fontWeight: active
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    color: active
                                                        ? f.color
                                                        : AppColors
                                                              .textSecondary,
                                                  ),
                                            ),
                                            if (isUnsettled &&
                                                unsettledCount > 0) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: f.color.withValues(
                                                    alpha: 0.25,
                                                  ),
                                                  borderRadius: isRetro
                                                      ? BorderRadius.zero
                                                      : BorderRadius.circular(
                                                          8,
                                                        ),
                                                  border: isRetro
                                                      ? Border.all(
                                                          color: AppColors
                                                              .cardBorder,
                                                          width: 1.0,
                                                        )
                                                      : null,
                                                ),
                                                child: Text(
                                                  '$unsettledCount',
                                                  style: AppTypography.tagChip
                                                      .copyWith(
                                                        color: f.color,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ] else if (_selectedTab == _WalletTab.goals) ...[
                        const SavingsGoalSection(),
                      ] else ...[
                        const FixedBillsSection(),
                      ],
                    ],
                  ),
                ),
              ),

              // ── 3. Date-Grouped Transaction List (Only when Transactions tab active) ───
              if (_selectedTab == _WalletTab.transactions) ...[
                if (groupedTxs.isEmpty)
                  SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: AppColors.isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: AppColors.isRetro ? 2.0 : 1.0,
                      ),
                      boxShadow: AppColors.isRetro
                          ? [
                              BoxShadow(
                                color: AppColors.retroShadowColor,
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            _filter == _TxFilter.all
                                ? Icons.receipt_long_outlined
                                : Icons.filter_list_off,
                            color: AppColors.textPlaceholder,
                            size: 32,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _filter == _TxFilter.all
                                ? 'No transactions for $monthFullLabel'
                                : 'No ${_filter.label.toLowerCase()} transactions',
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _filter == _TxFilter.all
                                ? 'Tap + Income or + Expense above'
                                : 'Try a different filter',
                            style: AppTypography.tagChip.copyWith(
                              color: AppColors.textPlaceholder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final dateKey = groupedTxs.keys.elementAt(index);
                      final dayTxs = groupedTxs[dateKey]!;
                      final firstTxDate = dayTxs.first.date;
                      final headerText = _formatDateHeader(firstTxDate);

                      // Calculate day total
                      double dayTotal = 0;
                      final repo = ref.read(walletRepositoryProvider);
                      for (final tx in dayTxs) {
                        if (tx.isSettled &&
                            (tx.expenseType == ExpenseType.borrowed ||
                                tx.expenseType == ExpenseType.lent) &&
                            !repo.hasSettledCounterpart(tx.id)) {
                          continue;
                        }
                        if (tx.direction == Direction.income) {
                          dayTotal += tx.amount;
                        } else if (tx.direction == Direction.expense) {
                          dayTotal -= tx.amount;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headerText,
                                  style: AppTypography.sectionLabel.copyWith(
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                    color: AppColors.textPlaceholder,
                                  ),
                                ),
                                if (dayTotal != 0)
                                  Text(
                                    dayTotal > 0
                                        ? '+৳${NumberFormat('#,##0').format(dayTotal.toInt())}'
                                        : '-৳${NumberFormat('#,##0').format((-dayTotal).toInt())}',
                                    style: AppTypography.scoreStat.copyWith(
                                      fontSize: 11,
                                      color: dayTotal > 0
                                          ? AppColors.successDone
                                          : AppColors.textPlaceholder,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ...dayTxs.map(
                            (tx) => TransactionRow(transaction: tx),
                          ),
                        ],
                      );
                    }, childCount: groupedTxs.length),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pixel Tab Bar for Wallet (Transactions | Goals | Bills) ───────────────────

class _WalletTabBar extends StatelessWidget {
  final _WalletTab selectedTab;
  final ValueChanged<_WalletTab> onTabChanged;

  const _WalletTabBar({
    required this.selectedTab,
    required this.onTabChanged,
  });

  Alignment _getAlignment(_WalletTab tab) {
    switch (tab) {
      case _WalletTab.transactions:
        return Alignment.centerLeft;
      case _WalletTab.goals:
        return Alignment.center;
      case _WalletTab.bills:
        return Alignment.centerRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Container(
      height: 42,
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
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          // Animated Sliding Indicator Thumb
          AnimatedAlign(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: _getAlignment(selectedTab),
            child: FractionallySizedBox(
              widthFactor: 1.0 / 3.0,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.accentPrimary.withValues(
                          alpha: AppColors.isDark ? 0.28 : 0.20,
                        )
                      : AppColors.accentPrimary.withValues(alpha: 0.15),
                  borderRadius:
                      isRetro ? BorderRadius.zero : BorderRadius.circular(9),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.accentPrimary
                        : AppColors.accentPrimary.withValues(alpha: 0.6),
                    width: isRetro ? 1.5 : 1.0,
                  ),
                  boxShadow: isRetro
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(1, 1),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          // Clickable Tab Buttons
          Row(
            children: _WalletTab.values.map((tab) {
              final isSelected = selectedTab == tab;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!isSelected) {
                      HapticFeedback.selectionClick();
                      onTabChanged(tab);
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          tab.label,
                          style: isRetro
                              ? RetroTypography.buttonLabel.copyWith(
                                  fontSize: 8.5,
                                  color: isSelected
                                      ? AppColors.accentPrimary
                                      : AppColors.textMuted,
                                )
                              : AppTypography.tagChip.copyWith(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.accentPrimary
                                      : AppColors.textSecondary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Staggered Card Entry Wrapper ─────────────────────────────────────────────

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

// ─── Minimalist Month Picker Bottom Sheet ─────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onSelected;

  const _MonthPickerSheet({
    required this.initialDate,
    required this.onSelected,
  });

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isRetro = AppColors.isRetro;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: isRetro
            ? Border.all(color: AppColors.cardBorder, width: 2.0)
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.cardBorder
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Year Selector Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _year--);
                  },
                ),
                Text(
                  '$_year',
                  style: AppTypography.displayHeading.copyWith(
                    fontSize: isRetro ? 16 : 20,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _year >= now.year
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.textSecondary,
                  ),
                  onPressed: _year >= now.year
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _year++);
                        },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 12 Months Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent:
                    56 * MediaQuery.textScalerOf(context).scale(14) / 14,
              ),
              itemBuilder: (context, i) {
                final month = i + 1;
                final isCurrentSelected =
                    widget.initialDate.year == _year &&
                    widget.initialDate.month == month;
                final isThisMonth = now.year == _year && now.month == month;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelected(DateTime(_year, month, 1));
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isCurrentSelected
                          ? AppColors.accentPrimary
                          : (isThisMonth
                                ? AppColors.accentPrimary.withValues(
                                    alpha: isRetro ? 0.25 : 0.15,
                                  )
                                : AppColors.appBackground),
                      borderRadius: isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentSelected
                            ? (isRetro
                                  ? AppColors.cardBorder
                                  : AppColors.accentPrimary)
                            : (isThisMonth
                                  ? (isRetro
                                        ? AppColors.cardBorder
                                        : AppColors.accentPrimary.withValues(
                                            alpha: 0.4,
                                          ))
                                  : (isRetro
                                        ? AppColors.cardBorder
                                        : Colors.white.withValues(
                                            alpha: 0.05,
                                          ))),
                        width: isRetro ? 1.5 : 1.0,
                      ),
                      boxShadow: (isRetro && isCurrentSelected)
                          ? [
                              BoxShadow(
                                color: AppColors.retroShadowColor,
                                offset: const Offset(2, 2),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _months[i],
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 13,
                          fontWeight: (isCurrentSelected || isThisMonth)
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isCurrentSelected
                              ? (isRetro && !AppColors.isDark
                                    ? AppColors.textPrimary
                                    : Colors.white)
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Quick Jump to Current Month
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onSelected(DateTime(now.year, now.month, 1));
                  Navigator.pop(context);
                },
                child: Text(
                  'Jump to Current Month',
                  style: AppTypography.buttonLabel.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
