import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../models/transaction.dart';
import '../../../providers/wallet_providers.dart';

class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  const TransactionRow({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    Color dotColor = AppColors.successDone;
    
    if (transaction.direction == Direction.income) {
      if (transaction.incomeSource == IncomeSource.other && transaction.expenseType == ExpenseType.lent) { // Borrowed returned? 
         dotColor = AppColors.successDone;
      } else {
         dotColor = AppColors.successDone;
      }
    } else {
      if (transaction.expenseType == ExpenseType.borrowed) dotColor = AppColors.errorAlert; // Red
      else if (transaction.expenseType == ExpenseType.lent) dotColor = AppColors.accentPrimary; // Blue
      else dotColor = AppColors.warningTag; // Amber
    }

    // Spec constraint: "Unsettled tag for borrowed money"
    // Borrowed = Came IN (Wait, if I borrow money, it's Income/Borrowed or Expense/Borrowed?)
    // Actually, prompt says: "Borrowed amounts count toward income/balance."
    // And: "Green=Income, Amber=Expense, Red=Borrowed, Blue=Lent"
    // Let's rely on expenseType to map the correct color overriding Income/Expense boundaries.
    
    if (transaction.expenseType == ExpenseType.borrowed) dotColor = AppColors.errorAlert;
    else if (transaction.expenseType == ExpenseType.lent) dotColor = AppColors.accentPrimary;

    bool isUnsettled = (transaction.expenseType == ExpenseType.borrowed || transaction.expenseType == ExpenseType.lent) && !transaction.isSettled;

    String dateStr = '${transaction.date.day.toString().padLeft(2, '0')}/${transaction.date.month.toString().padLeft(2, '0')}';
    
    String prefix = transaction.direction == Direction.income ? '+' : '-';
    // However, if we borrow money, balance goes up (handled in repository).

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF141418)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
             width: 12, height: 12,
             decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                       child: Text(
                          transaction.note.isEmpty ? (transaction.expenseType?.name ?? transaction.incomeSource?.name ?? 'Transaction') : transaction.note,
                          style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                       ),
                    ),
                    if (isUnsettled)
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                             color: AppColors.errorAlert.withValues(alpha: 0.1),
                             borderRadius: BorderRadius.circular(4),
                             border: Border.all(color: AppColors.errorAlert.withValues(alpha: 0.3))
                          ),
                          child: Text('Unsettled', style: AppTypography.navLabel.copyWith(color: AppColors.errorAlert)),
                       )
                  ],
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: AppTypography.sectionLabel),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
             '$prefix${currencyFormat.format(transaction.amount)}',
             style: AppTypography.scoreStat.copyWith(fontSize: 15, color: transaction.direction == Direction.income ? AppColors.successDone : AppColors.textPrimary),
          )
        ],
      ),
    );
  }
}
