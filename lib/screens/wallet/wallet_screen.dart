import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/wallet_providers.dart';
import '../../models/transaction.dart';
import '../../models/wallet_settings.dart';
import 'package:hive/hive.dart';
import 'widgets/transaction_row.dart';
import 'widgets/budget_bar.dart';
import 'widgets/savings_goal_card.dart';
import 'transaction_sheet.dart';
import '../../widgets/action_button.dart';
import 'widgets/fixed_bills_section.dart';
import 'wallet_settings_sheet.dart';

// Number-only formatter (no symbol) for split rendering of the balance
final _numFormat = NumberFormat('#,##0.00', 'en_US');

// ── Filter enum ───────────────────────────────────────────────────────────────
enum _TxFilter {
  all,
  income,
  expense,
  borrowed,
  lent,
  unsettled,
}

extension _TxFilterLabel on _TxFilter {
  String get label {
    switch (this) {
      case _TxFilter.all:       return 'All';
      case _TxFilter.income:    return 'Income';
      case _TxFilter.expense:   return 'Expense';
      case _TxFilter.borrowed:  return 'Borrowed';
      case _TxFilter.lent:      return 'Lent';
      case _TxFilter.unsettled: return 'Unsettled';
    }
  }

  Color get color {
    switch (this) {
      case _TxFilter.all:       return AppColors.accentPrimary;
      case _TxFilter.income:    return AppColors.successDone;
      case _TxFilter.expense:   return AppColors.warningTag;
      case _TxFilter.borrowed:  return AppColors.errorAlert;
      case _TxFilter.lent:      return AppColors.accentPrimary;
      case _TxFilter.unsettled: return const Color(0xFFE5A93D);
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _TxFilter _filter = _TxFilter.all;

  void _showAddSheet(bool isIncome) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionSheet(initialIsIncome: isIncome),
    );
  }

  void _showIouSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransactionSheet(
        initialIsIncome: false,
        startAsBorrowLend: true,
      ),
    );
  }

  String _monthLabel() {
    const months = [
      'JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE',
      'JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  double _monthProgress() {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    return now.day / daysInMonth;
  }

  // ── Filter logic ────────────────────────────────────────────────────────────
  List<Transaction> _applyFilter(List<Transaction> txs) {
    switch (_filter) {
      case _TxFilter.all:
        return txs;
      case _TxFilter.income:
        return txs.where((t) =>
            t.direction == Direction.income &&
            t.expenseType != ExpenseType.borrowed).toList();
      case _TxFilter.expense:
        return txs.where((t) =>
            t.direction == Direction.expense &&
            t.expenseType != ExpenseType.lent &&
            t.expenseType != ExpenseType.borrowed).toList();
      case _TxFilter.borrowed:
        return txs.where((t) => t.expenseType == ExpenseType.borrowed).toList();
      case _TxFilter.lent:
        return txs.where((t) => t.expenseType == ExpenseType.lent).toList();
      case _TxFilter.unsettled:
        return txs.where((t) =>
            !t.isSettled &&
            (t.expenseType == ExpenseType.borrowed ||
             t.expenseType == ExpenseType.lent)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance        = ref.watch(runningBalanceProvider);
    final openingBalance = ref.watch(openingBalanceProvider);
    final txs            = ref.watch(currentTransactionsProvider);

    double income = 0;
    double spent  = 0;
    for (var tx in txs) {
      if (tx.expenseType == ExpenseType.borrowed || tx.expenseType == ExpenseType.lent) { continue; }
      if (tx.direction == Direction.income) { income += tx.amount; }
      else if (tx.direction == Direction.expense) { spent += tx.amount; }
    }

    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings    = settingsBox.isEmpty ? WalletSettings() : settingsBox.getAt(0)!;
    final saved       = openingBalance + income - spent;
    final now         = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    final filtered = _applyFilter(txs);

    // Count unsettled IOUs for the badge on the filter
    final unsettledCount = txs.where((t) =>
        !t.isSettled &&
        (t.expenseType == ExpenseType.borrowed ||
         t.expenseType == ExpenseType.lent)).length;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            // ── Inline header ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _monthLabel(),
                      style: AppTypography.sectionLabel.copyWith(
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Wallet', style: AppTypography.displayHeading),
                        GestureDetector(
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const WalletSettingsSheet(),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF161619),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1E1E26)),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF666672),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Month progress pill ──────────────────────────────────
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E26),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: _monthProgress(),
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPrimary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Day ${now.day} of $daysInMonth',
                                style: AppTypography.bodyText.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Main content ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Balance card ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1A1A24)),
                      ),
                      child: Column(
                        children: [
                          Text('CURRENT BALANCE', style: AppTypography.sectionLabel),
                          const SizedBox(height: 8),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '৳',
                                  style: AppTypography.displayHeading.copyWith(
                                    fontSize: 22,
                                    color: AppColors.accentPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: _numFormat.format(balance),
                                  style: AppTypography.displayHeading.copyWith(fontSize: 34),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (income > 0 || spent > 0)
                                ? 'Carried from previous month: ${currencyFormat.format(openingBalance)}'
                                : 'Opening balance this month: ${currencyFormat.format(openingBalance)}',
                            style: AppTypography.bodyText.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Container(height: 1, color: const Color(0xFF1A1A24)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatColumn('Income', income, AppColors.successDone, false),
                              _StatColumn('Spent',  spent,  AppColors.textPrimary,  false),
                              _StatColumn('Saved',  saved,  AppColors.accentPrimary, true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Action buttons ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IntrinsicWidth(
                          child: ActionButton(
                            icon: Icons.download,
                            label: '+ Income',
                            color: AppColors.successDone,
                            onTap: () => _showAddSheet(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IntrinsicWidth(
                          child: ActionButton(
                            icon: Icons.upload,
                            label: '+ Expense',
                            color: AppColors.warningTag,
                            onTap: () => _showAddSheet(false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IntrinsicWidth(
                          child: ActionButton(
                            icon: Icons.handshake_outlined,
                            label: '+ IOU',
                            color: AppColors.accentPrimary,
                            onTap: () => _showIouSheet(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    BudgetBar(spent: spent, limit: settings.monthlyBudget),
                    SavingsGoalCard(saved: saved, goal: settings.semesterGoal),
                    const SizedBox(height: 28),

                    // ── Fixed Bills ───────────────────────────────────────────
                    const FixedBillsSection(),
                    const SizedBox(height: 28),

                    // ── Transactions header ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: const Color(0xFF1A1A24))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'TRANSACTIONS',
                            style: AppTypography.sectionLabel.copyWith(
                              color: const Color(0xFF444450),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: const Color(0xFF1A1A24))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Filter chips ──────────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _TxFilter.values.map((f) {
                          final active = _filter == f;
                          final isUnsettled = f == _TxFilter.unsettled;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: active
                                      ? f.color.withValues(alpha: 0.15)
                                      : const Color(0xFF121217),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? f.color.withValues(alpha: 0.6)
                                        : const Color(0xFF1E1E26),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      f.label,
                                      style: AppTypography.bodyText.copyWith(
                                        fontSize: 12,
                                        color: active ? f.color : AppColors.textMuted,
                                      ),
                                    ),
                                    // Badge: unsettled count on the Unsettled chip
                                    if (isUnsettled && unsettledCount > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: f.color.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$unsettledCount',
                                          style: AppTypography.navLabel.copyWith(
                                            color: f.color,
                                            fontSize: 10,
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
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),

            // ── Transaction list (filtered) ───────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: filtered.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 32),
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1A1A24)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _filter == _TxFilter.all
                                  ? Icons.receipt_long_outlined
                                  : Icons.filter_list_off,
                              color: AppColors.textPlaceholder,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filter == _TxFilter.all
                                  ? 'No transactions yet'
                                  : 'No ${_filter.label.toLowerCase()} transactions',
                              style: AppTypography.bodyText
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _filter == _TxFilter.all
                                  ? 'Tap + Income or + Expense above'
                                  : 'Try a different filter',
                              style: AppTypography.sectionLabel,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            TransactionRow(transaction: filtered[index]),
                        childCount: filtered.length,
                      ),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Stat column ───────────────────────────────────────────────────────────────
class _StatColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool highlighted;

  const _StatColumn(this.label, this.amount, this.color, this.highlighted);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: highlighted
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.15)),
            )
          : null,
      child: Column(
        children: [
          Text(label, style: AppTypography.sectionLabel),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(amount),
            style: AppTypography.scoreStat.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
