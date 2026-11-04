import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../models/transaction.dart';
import '../../../providers/wallet_providers.dart';

// ── Human-readable labels ─────────────────────────────────────────────────────
const _typeLabels = {
  'fixed':     'Recurring Bill',
  'variable':  'Expense',
  'borrowed':  'Borrowed',
  'lent':      'Lent',
  'transport': 'Transport',
  'snacks':    'Snacks',
  'shopping':  'Shopping',
  'fees':      'Fees',
  'other':     'Other',
};
const _srcLabels = {
  'tuition':  'Tuition',
  'freelance': 'Work',
  'work':     'Work',
  'gift':     'Gift',
  'other':    'Other',
};

class TransactionRow extends ConsumerWidget {
  final Transaction transaction;
  const TransactionRow({super.key, required this.transaction});

  IconData _getCategoryIcon() {
    if (transaction.direction == Direction.income) {
      switch (transaction.incomeSource) {
        case IncomeSource.tuition:
          return Icons.school_rounded;
        case IncomeSource.work:
        case IncomeSource.freelance:
          return Icons.work_rounded;
        case IncomeSource.gift:
          return Icons.card_giftcard_rounded;
        default:
          return Icons.arrow_downward_rounded;
      }
    } else {
      switch (transaction.expenseType) {
        case ExpenseType.transport:
          return Icons.directions_subway_rounded;
        case ExpenseType.snacks:
          return Icons.local_cafe_rounded;
        case ExpenseType.shopping:
          return Icons.shopping_bag_rounded;
        case ExpenseType.fees:
          return Icons.school_rounded;
        case ExpenseType.fixed:
          return Icons.receipt_long_rounded;
        case ExpenseType.borrowed:
          return Icons.call_received_rounded;
        case ExpenseType.lent:
          return Icons.call_made_rounded;
        default:
          return Icons.credit_card_rounded;
      }
    }
  }

  Color _getCategoryColor() {
    if (transaction.expenseType == ExpenseType.borrowed) {
      return AppColors.errorAlert;
    } else if (transaction.expenseType == ExpenseType.lent) {
      return AppColors.accentPrimary;
    } else if (transaction.direction == Direction.income) {
      return AppColors.successDone;
    } else {
      return AppColors.warningTag;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIou =
        transaction.expenseType == ExpenseType.borrowed ||
        transaction.expenseType == ExpenseType.lent;

    final Color catColor = _getCategoryColor();
    final bool isPositive = transaction.direction == Direction.income;
    final String prefix = isPositive ? '+' : '-';

    final String categoryName = transaction.expenseType != null
        ? (_typeLabels[transaction.expenseType!.name] ?? transaction.expenseType!.name)
        : (_srcLabels[transaction.incomeSource?.name ?? ''] ??
            transaction.incomeSource?.name ??
            'General');

    final String displayTitle =
        transaction.note.isEmpty ? categoryName : transaction.note;

    final bool isUnsettled = isIou && !transaction.isSettled;

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final String dateStr =
        '${transaction.date.day} ${months[transaction.date.month - 1]}';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showActions(context, ref);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showActions(context, ref);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category Icon Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getCategoryIcon(), color: catColor, size: 18),
            ),
            const SizedBox(width: 14),

            // Title + Category/Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: (transaction.isSettled && isIou)
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            decoration: (transaction.isSettled && isIou)
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnsettled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppColors.errorAlert.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unsettled',
                            style: AppTypography.tagChip.copyWith(
                              color: AppColors.errorAlert,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (transaction.isSettled && isIou)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.successDone,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.note.isNotEmpty ? '$categoryName · $dateStr' : dateStr,
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount
            Text(
              '$prefix${currencyFormat.format(transaction.amount)}',
              style: AppTypography.scoreStat.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPositive ? AppColors.successDone : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Long-press action sheet ───────────────────────────────────────────────

  void _showActions(BuildContext context, WidgetRef ref) {
    final isIou =
        transaction.expenseType == ExpenseType.borrowed ||
        transaction.expenseType == ExpenseType.lent;
    final canSettle = isIou && !transaction.isSettled;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getCategoryColor(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transaction.note.isEmpty ? 'Transaction' : transaction.note,
                    style: AppTypography.cardTitle.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  currencyFormat.format(transaction.amount),
                  style: AppTypography.scoreStat.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 12),

            // Settle button
            if (canSettle) ...[
              _ModalOption(
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.successDone,
                label: 'Mark as Settled',
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(walletNotifierProvider.notifier)
                      .settleTransaction(transaction);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Marked as settled'),
                        backgroundColor: AppColors.successDone,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],

            // Delete button
            _ModalOption(
              icon: Icons.delete_outline_rounded,
              iconColor: AppColors.errorAlert,
              label: 'Delete Transaction',
              isDestructive: true,
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Delete Transaction', style: AppTypography.headline),
                    content: Text(
                      'Are you sure you want to delete this transaction of ${currencyFormat.format(transaction.amount)}?',
                      style: AppTypography.bodyText,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: AppTypography.buttonLabel.copyWith(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Delete', style: AppTypography.buttonLabel.copyWith(color: AppColors.errorAlert)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(walletNotifierProvider.notifier)
                      .deleteTransaction(transaction.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ModalOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.errorAlert.withValues(alpha: 0.08) : AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTypography.buttonLabel.copyWith(
                color: isDestructive ? AppColors.errorAlert : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
