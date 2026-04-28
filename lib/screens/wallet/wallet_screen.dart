import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  void _showAddSheet(BuildContext context, bool isIncome) {
     showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TransactionSheet(initialIsIncome: isIncome)
     );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(runningBalanceProvider);
    final openingBalance = ref.watch(openingBalanceProvider);
    final txs = ref.watch(currentTransactionsProvider);
    
    double income = 0; double spent = 0;
    for (var tx in txs) {
       if (tx.direction == Direction.income) income += tx.amount;
       else if (tx.direction == Direction.expense && tx.expenseType != ExpenseType.borrowed) spent += tx.amount;
    }
    
    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings = settingsBox.isEmpty ? WalletSettings() : settingsBox.getAt(0)!;

    // Saved = opening balance carried in + net this month
    final saved = openingBalance + income - spent;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
         title: Text('Wallet', style: AppTypography.displayHeading), 
         backgroundColor: AppColors.appBackground,
         elevation: 0,
         bottom: PreferredSize(
           preferredSize: const Size.fromHeight(22),
           child: Padding(
             padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
             child: Align(
               alignment: Alignment.centerLeft,
               child: Text(
                 () {
                   const months = ['JANUARY','FEBRUARY','MARCH','APRIL','MAY','JUNE','JULY','AUGUST','SEPTEMBER','OCTOBER','NOVEMBER','DECEMBER'];
                   final now = DateTime.now();
                   return '${months[now.month - 1]} ${now.year}';
                 }(),
                 style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary),
               ),
             ),
           ),
         ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                     decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16)
                     ),
                     child: Column(
                        children: [
                           Text('CURRENT BALANCE', style: AppTypography.sectionLabel),
                           const SizedBox(height: 8),
                           Text(currencyFormat.format(balance), style: AppTypography.displayHeading.copyWith(fontSize: 32)),
                           const SizedBox(height: 4),
                           Text(
                             (income > 0 || spent > 0)
                               ? 'Carried from previous month: ${currencyFormat.format(openingBalance)}'
                               : 'Opening balance this month: ${currencyFormat.format(openingBalance)}',
                             style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 13),
                           ),
                           const SizedBox(height: 24),
                           Container(height: 1, color: const Color(0xFF1A1A24)),
                           const SizedBox(height: 16),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               _StatColumn('Income', income, AppColors.successDone),
                               _StatColumn('Spent', spent, AppColors.textPrimary),
                               _StatColumn('Saved', saved, AppColors.accentPrimary),
                             ],
                           )                        ]
                     )
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: ActionButton(icon: Icons.download, label: 'Add income', color: AppColors.successDone, onTap: () => _showAddSheet(context, true))),
                      const SizedBox(width: 16),
                      Expanded(child: ActionButton(icon: Icons.upload, label: 'Add expense', color: AppColors.warningTag, onTap: () => _showAddSheet(context, false))),
                    ]
                  ),
                  const SizedBox(height: 32),
                  BudgetBar(spent: spent, limit: settings.monthlyBudget),
                  SavingsGoalCard(saved: saved, goal: settings.semesterGoal),
                  
                  const SizedBox(height: 32),
                  const FixedBillsSection(),
                  const SizedBox(height: 32),

                  Text('TRANSACTIONS', style: AppTypography.sectionLabel),
                  const SizedBox(height: 16),
                ]
              )
            )
          ),
          SliverPadding(
             padding: const EdgeInsets.symmetric(horizontal: 24.0),
             sliver: txs.isEmpty
               ? SliverToBoxAdapter(
                   child: Container(
                     margin: const EdgeInsets.only(top: 8, bottom: 32),
                     padding: const EdgeInsets.symmetric(vertical: 28),
                     decoration: BoxDecoration(
                       color: AppColors.cardBackground,
                       borderRadius: BorderRadius.circular(14),
                       border: Border.all(color: const Color(0xFF1A1A24)),
                     ),
                     child: Column(
                       children: [
                         Icon(Icons.receipt_long_outlined, color: AppColors.textPlaceholder, size: 28),
                         const SizedBox(height: 10),
                         Text('No transactions yet', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted)),
                         const SizedBox(height: 4),
                         Text('Tap + Income or + Expense above', style: AppTypography.sectionLabel),
                       ],
                     ),
                   ),
                 )
               : SliverList(
                   delegate: SliverChildBuilderDelegate(
                     (context, index) => TransactionRow(transaction: txs[index]),
                     childCount: txs.length,
                   ),
                 ),
          )
        ]
      )
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _StatColumn(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
      return Column(
         children: [
            Text(label, style: AppTypography.sectionLabel),
            const SizedBox(height: 4),
            Text(currencyFormat.format(amount), style: AppTypography.scoreStat.copyWith(color: color)),
         ]
      );
  }
}
