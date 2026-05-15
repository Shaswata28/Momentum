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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIou =
        transaction.expenseType == ExpenseType.borrowed ||
        transaction.expenseType == ExpenseType.lent;

    // ── Dot color ─────────────────────────────────────────────────────────
    final Color dotColor;
    if (transaction.expenseType == ExpenseType.borrowed) {
      dotColor = AppColors.errorAlert;
    } else if (transaction.expenseType == ExpenseType.lent) {
      dotColor = AppColors.accentPrimary;
    } else if (transaction.direction == Direction.income) {
      dotColor = AppColors.successDone;
    } else {
      dotColor = AppColors.warningTag;
    }

    // ── +/- prefix ────────────────────────────────────────────────────────
    // Borrowed = money came IN (+), Lent = money went OUT (-)
    final bool isPositive =
        transaction.direction == Direction.income;
    final String prefix = isPositive ? '+' : '-';

    // ── Label ─────────────────────────────────────────────────────────────
    final String fallback = transaction.expenseType != null
        ? (_typeLabels[transaction.expenseType!.name] ?? transaction.expenseType!.name)
        : (_srcLabels[transaction.incomeSource?.name ?? ''] ??
            transaction.incomeSource?.name ??
            'Transaction');
    final String label =
        transaction.note.isEmpty ? fallback : transaction.note;

    final bool isUnsettled = isIou && !transaction.isSettled;

    final String dateStr =
        '${transaction.date.day.toString().padLeft(2, '0')}/${transaction.date.month.toString().padLeft(2, '0')}';

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showActions(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF141418))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: transaction.isSettled && isIou
                    ? dotColor.withValues(alpha: 0.35)
                    : dotColor,
              ),
            ),
            const SizedBox(width: 14),

            // Label + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.bodyText.copyWith(
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppColors.errorAlert.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.errorAlert.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Unsettled',
                            style: AppTypography.navLabel
                                .copyWith(color: AppColors.errorAlert),
                          ),
                        ),
                      if (transaction.isSettled && isIou)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.check_circle,
                              size: 14, color: AppColors.successDone),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(dateStr, style: AppTypography.sectionLabel),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount
            Text(
              '$prefix${currencyFormat.format(transaction.amount)}',
              style: AppTypography.scoreStat.copyWith(
                fontSize: 14,
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
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color(0xFF1A1A24))),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: transaction.expenseType == ExpenseType.borrowed
                        ? AppColors.errorAlert
                        : transaction.expenseType == ExpenseType.lent
                            ? AppColors.accentPrimary
                            : transaction.direction == Direction.income
                                ? AppColors.successDone
                                : AppColors.warningTag,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transaction.note.isEmpty
                        ? (_typeLabels[transaction.expenseType?.name ?? ''] ??
                            transaction.incomeSource?.name ??
                            'Transaction')
                        : transaction.note,
                    style: AppTypography.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  currencyFormat.format(transaction.amount),
                  style: AppTypography.scoreStat.copyWith(
                    color: transaction.direction == Direction.income
                        ? AppColors.successDone
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF1A1A24), height: 1),
            const SizedBox(height: 16),

            // Settle action (IOU only)
            if (canSettle) ...[
              _ActionRow(
                icon: Icons.handshake_outlined,
                label: transaction.expenseType == ExpenseType.borrowed
                    ? 'Mark as repaid (paid back)'
                    : 'Mark as received (got money back)',
                color: AppColors.successDone,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(walletNotifierProvider.notifier)
                      .settleTransaction(transaction);
                },
              ),
              const SizedBox(height: 4),
            ],

            // Delete action
            _ActionRow(
              icon: Icons.delete_outline,
              label: 'Delete transaction',
              color: AppColors.errorAlert,
              onTap: () {
                Navigator.pop(context);
                ref.read(walletNotifierProvider.notifier)
                    .deleteTransaction(transaction.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action row item ───────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(label, style: AppTypography.bodyText.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}