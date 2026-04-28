import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../models/fixed_expense.dart';
import '../../../models/transaction.dart';
import '../../../providers/wallet_providers.dart';
import '../../../widgets/action_button.dart';

class FixedBillsSection extends ConsumerWidget {
  const FixedBillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixedExpenses = ref.watch(fixedExpensesProvider);
    final monthId = ref.watch(currentMonthIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FIXED BILLS', style: AppTypography.sectionLabel),
            GestureDetector(
              onTap: () => _showAddSheet(context, ref),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.add, color: AppColors.accentPrimary, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Empty state ─────────────────────────────────────────────
        if (fixedExpenses.isEmpty)
          Container(
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
                Text('No recurring bills', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text('Tap + above to add one', style: AppTypography.sectionLabel),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1A1A24)),
            ),
            child: Column(
              children: fixedExpenses.asMap().entries.map((entry) {
                final isLast = entry.key == fixedExpenses.length - 1;
                return _BillRow(
                  expense: entry.value,
                  monthId: monthId,
                  isLast: isLast,
                  onMarkPaid: () => _markPaid(ref, entry.value, monthId),
                  onDelete: () => ref.read(walletNotifierProvider.notifier).deleteFixedExpense(entry.value.id),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _markPaid(WidgetRef ref, FixedExpense expense, String currentMonthId) async {
    HapticFeedback.mediumImpact();
    final tx = Transaction(
      id: const Uuid().v4(),
      date: DateTime.now(),
      direction: Direction.expense,
      amount: expense.amount,
      expenseType: ExpenseType.variable,
      note: expense.name,
      isSettled: true,
      monthId: currentMonthId,
    );
    await ref.read(walletNotifierProvider.notifier).addTransaction(tx);

    final updated = FixedExpense(
      id: expense.id,
      name: expense.name,
      amount: expense.amount,
      billingDay: expense.billingDay,
      lastPaidMonthKey: currentMonthId,
    );
    await ref.read(walletNotifierProvider.notifier).addFixedExpense(updated);
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBillSheet(ref: ref),
    );
  }
}

// ── Individual bill row ───────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  final FixedExpense expense;
  final String monthId;
  final bool isLast;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _BillRow({
    required this.expense,
    required this.monthId,
    required this.isLast,
    required this.onMarkPaid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = expense.lastPaidMonthKey == monthId;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showDeleteDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFF141418))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dot indicator
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPaid ? AppColors.successDone : AppColors.warningTag,
              ),
            ),
            // Name + due date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.name,
                    style: AppTypography.bodyText.copyWith(
                      color: isPaid ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Due ${_ordinal(expense.billingDay)} each month',
                    style: AppTypography.sectionLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount + action
            if (isPaid)
              Row(
                children: [
                  Text(
                    currencyFormat.format(expense.amount),
                    style: AppTypography.scoreStat.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: AppColors.successDone, size: 20),
                ],
              )
            else
              Row(
                children: [
                  Text(
                    currencyFormat.format(expense.amount),
                    style: AppTypography.scoreStat.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onMarkPaid,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Pay',
                        style: AppTypography.navLabel.copyWith(
                          color: AppColors.accentPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1A1A24)),
        ),
        title: Text('Remove Bill?', style: AppTypography.displayHeading.copyWith(fontSize: 18)),
        content: Text(
          'Remove "${expense.name}" from recurring bills?',
          style: AppTypography.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.buttonLabel.copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: Text('Remove', style: AppTypography.buttonLabel.copyWith(color: AppColors.errorAlert)),
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
}

// ── Add bill bottom sheet ─────────────────────────────────────────────────────

class _AddBillSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddBillSheet({required this.ref});

  @override
  State<_AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<_AddBillSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final day = int.tryParse(_dayCtrl.text) ?? 0;
    if (name.isEmpty || amount <= 0 || day < 1 || day > 31) return;

    final expense = FixedExpense(
      id: const Uuid().v4(),
      name: name,
      amount: amount,
      billingDay: day,
    );
    widget.ref.read(walletNotifierProvider.notifier).addFixedExpense(expense);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardSpace),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Recurring Bill', style: AppTypography.displayHeading),
            const SizedBox(height: 28),

            // Name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: AppTypography.bodyText,
                decoration: InputDecoration(
                  hintText: 'Bill name (e.g. Internet, Rent)',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.bodyText,
                decoration: InputDecoration(
                  hintText: 'Amount',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  prefixText: '৳ ',
                  prefixStyle: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Billing day
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _dayCtrl,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyText,
                decoration: InputDecoration(
                  hintText: 'Billing day of month (1 – 31)',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            ActionButton(
              icon: Icons.check,
              label: 'SAVE BILL',
              color: AppColors.accentPrimary,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
