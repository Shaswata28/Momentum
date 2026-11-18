import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/retro_typography.dart';
import '../../../models/transaction.dart';
import '../../../models/category_meta.dart';
import '../../../providers/wallet_providers.dart';
import '../transaction_sheet.dart';

class TransactionRow extends ConsumerWidget {
  final Transaction transaction;
  const TransactionRow({super.key, required this.transaction});

  IconData _getCategoryIcon() {
    if (transaction.direction == Direction.income) {
      return CategoryMeta.forIncome(transaction.incomeSource).icon;
    } else {
      return CategoryMeta.forExpense(transaction.expenseType).icon;
    }
  }

  Color _getCategoryColor() {
    if (transaction.expenseType == ExpenseType.borrowed) {
      return AppColors.errorAlert;
    } else if (transaction.expenseType == ExpenseType.lent) {
      return AppColors.accentPrimary;
    } else if (transaction.direction == Direction.income) {
      return CategoryMeta.forIncome(transaction.incomeSource).color;
    } else {
      return CategoryMeta.forExpense(transaction.expenseType).color;
    }
  }

  String _getCategoryLabel() {
    if (transaction.direction == Direction.income) {
      return CategoryMeta.forIncome(transaction.incomeSource).label;
    } else {
      return CategoryMeta.forExpense(transaction.expenseType).label;
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

    final String categoryName = _getCategoryLabel();

    final String displayTitle = transaction.note.isEmpty
        ? categoryName
        : transaction.note;

    final bool isUnsettled = isIou && !transaction.isSettled;

    const months = [
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
    final String dateStr =
        '${transaction.date.day} ${months[transaction.date.month - 1]}';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showActions(context, ref);
      },
      onLongPress: () {
        HapticFeedback.selectionClick();
        _showActions(context, ref);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.isRetro
                  ? AppColors.dividerBorderHover
                  : Colors.white.withValues(alpha: 0.05),
              width: AppColors.isRetro ? 1.5 : 1.0,
            ),
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
                color: catColor.withValues(
                  alpha: AppColors.isRetro ? 0.2 : 0.12,
                ),
                borderRadius: AppColors.isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(10),
                border: AppColors.isRetro
                    ? Border.all(color: AppColors.cardBorder, width: 1.5)
                    : null,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                    transaction.note.isNotEmpty
                        ? '$categoryName · $dateStr'
                        : dateStr,
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$prefix${currencyFormat.format(transaction.amount)}',
                    style: AppTypography.scoreStat.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? AppColors.successDone
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: AppColors.isRetro
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: AppColors.isRetro
                ? AppColors.cardBorder
                : Colors.white.withValues(alpha: 0.08),
            width: AppColors.isRetro ? 2.0 : 1.0,
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).padding.bottom + 24,
        ),
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
                  color: AppColors.isRetro
                      ? AppColors.cardBorder
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppColors.isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getCategoryColor(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transaction.note.isEmpty ? 'Transaction' : transaction.note,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
            Divider(
              color: AppColors.isRetro
                  ? AppColors.dividerBorderHover
                  : Colors.white.withValues(alpha: 0.06),
              height: 1,
            ),
            const SizedBox(height: 12),

            // Edit button
            _ModalOption(
              icon: Icons.edit_outlined,
              iconColor: AppColors.accentPrimary,
              label: 'Edit Transaction',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => TransactionSheet(
                    initialIsIncome: transaction.direction == Direction.income,
                    transactionToEdit: transaction,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Settle button
            if (canSettle) ...[
              _ModalOption(
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.successDone,
                label: 'Record repayment today',
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(walletNotifierProvider.notifier)
                        .settleTransaction(transaction);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Repayment recorded today. The original entry date is unchanged.',
                          ),
                          backgroundColor: AppColors.successDone,
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not record repayment. Please retry.',
                          ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: AppColors.isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(16),
                      side: AppColors.isRetro
                          ? BorderSide(color: AppColors.cardBorder, width: 2.0)
                          : BorderSide.none,
                    ),
                    title: Text(
                      'Delete Transaction',
                      style: AppColors.isRetro
                          ? RetroTypography.displayHeading.copyWith(fontSize: 14)
                          : AppTypography.headline,
                    ),
                    content: Text(
                      'Delete this transaction of ${currencyFormat.format(transaction.amount)}? Any linked repayment will also be deleted. This cannot be undone.',
                      style: AppColors.isRetro
                          ? RetroTypography.bodyText.copyWith(fontSize: 11)
                          : AppTypography.bodyText,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'Cancel',
                          style: AppTypography.buttonLabel.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Delete',
                          style: AppTypography.buttonLabel.copyWith(
                            color: AppColors.errorAlert,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  HapticFeedback.mediumImpact();
                  try {
                    await ref
                        .read(walletNotifierProvider.notifier)
                        .deleteTransaction(transaction.id);
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not delete transaction. Please retry.',
                          ),
                        ),
                      );
                  }
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
    final isRetro = AppColors.isRetro;

    return InkWell(
      onTap: onTap,
      borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? (isRetro
                  ? AppColors.errorAlert.withValues(alpha: 0.15)
                  : AppColors.errorAlert.withValues(alpha: 0.08))
              : (isRetro
                  ? AppColors.cardBackground
                  : AppColors.elevatedSurface),
          borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(12),
          border: isRetro
              ? Border.all(
                  color: isDestructive ? AppColors.errorAlert : AppColors.cardBorder,
                  width: 1.5,
                )
              : null,
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
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: isRetro
                    ? RetroTypography.buttonLabel.copyWith(
                        color: isDestructive
                            ? AppColors.errorAlert
                            : AppColors.textPrimary,
                        fontSize: 10,
                      )
                    : AppTypography.buttonLabel.copyWith(
                        color: isDestructive
                            ? AppColors.errorAlert
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
