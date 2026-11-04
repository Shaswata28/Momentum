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
                child: Icon(Icons.add, color: AppColors.accentPrimary, size: 16),
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: fixedExpenses.asMap().entries.map((entry) {
                final isLast = entry.key == fixedExpenses.length - 1;
                return _BillRow(
                  expense: entry.value,
                  monthId: monthId,
                  isLast: isLast,
                  onMarkPaid: () => _markPaid(context, ref, entry.value, monthId),
                  onDelete: () => ref.read(walletNotifierProvider.notifier).deleteFixedExpense(entry.value.id),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _markPaid(BuildContext context, WidgetRef ref, FixedExpense expense, String currentMonthId) async {
    HapticFeedback.mediumImpact();
    final tx = Transaction(
      id: const Uuid().v4(),
      date: DateTime.now(),
      direction: Direction.expense,
      amount: expense.amount,
      expenseType: ExpenseType.fixed,
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

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Paid ${expense.name} (৳${expense.amount.toInt()})'),
            ],
          ),
          backgroundColor: AppColors.successDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
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

class _BillRow extends StatefulWidget {
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
  State<_BillRow> createState() => _BillRowState();
}

class _BillRowState extends State<_BillRow> {
  bool _isProcessing = false;

  void _handlePay() {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _isProcessing = false);
      widget.onMarkPaid();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.expense.lastPaidMonthKey == widget.monthId;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showDeleteDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: widget.isLast
              ? null
              : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isPaid || _isProcessing) ? AppColors.successDone : AppColors.warningTag,
              ),
            ),
            // Name + due date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.expense.name,
                    style: AppTypography.bodyText.copyWith(
                      color: isPaid ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Due ${_ordinal(widget.expense.billingDay)} each month',
                    style: AppTypography.sectionLabel.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
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
                    currencyFormat.format(widget.expense.amount),
                    style: AppTypography.scoreStat.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_rounded, color: AppColors.successDone, size: 20),
                ],
              )
            else
              Row(
                children: [
                  Text(
                    currencyFormat.format(widget.expense.amount),
                    style: AppTypography.scoreStat.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isProcessing ? null : _handlePay,
                    child: AnimatedScale(
                      scale: _isProcessing ? 0.92 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isProcessing
                              ? AppColors.successDone
                              : AppColors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isProcessing
                                ? AppColors.successDone
                                : AppColors.accentPrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isProcessing) ...[
                              const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _isProcessing ? 'Paid' : 'Pay',
                              style: AppTypography.buttonLabel.copyWith(
                                color: _isProcessing ? Colors.white : AppColors.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Text('Remove Bill?', style: AppTypography.headline),
        content: Text(
          'Remove "${widget.expense.name}" from recurring bills?',
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
              widget.onDelete();
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
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + keyboardSpace),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────
            Center(
              child: Container(
                width: 38, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('New Recurring Bill', style: AppTypography.titleLarge),
            const SizedBox(height: 20),

            // Name
            Text('BILL NAME', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: TextField(
                controller: _nameCtrl,
                style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'e.g. Internet, Rent, Spotify',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textPlaceholder),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            Text('AMOUNT', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.scoreStat.copyWith(color: AppColors.textPrimary, fontSize: 16),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: AppTypography.scoreStat.copyWith(color: AppColors.textPlaceholder),
                  prefixText: '৳ ',
                  prefixStyle: AppTypography.scoreStat.copyWith(color: AppColors.accentPrimary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Billing Day
            Text('DUE DAY OF MONTH', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: TextField(
                controller: _dayCtrl,
                keyboardType: TextInputType.number,
                style: AppTypography.scoreStat.copyWith(color: AppColors.textPrimary, fontSize: 16),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'Day (1–31)',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textPlaceholder),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            ActionButton(
              icon: Icons.check_rounded,
              label: 'Add Bill',
              isPrimary: true,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
