import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/wallet_providers.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/action_button.dart';

// ── Mode enum ─────────────────────────────────────────────────────────────────
enum _TxMode { income, expense, borrowLend }

// ── Human-readable labels ─────────────────────────────────────────────────────
const _expenseLabels = {
  ExpenseType.transport: 'Transport',
  ExpenseType.snacks:    'Snacks',
  ExpenseType.shopping:  'Shopping',
  ExpenseType.fees:      'Fees',
  ExpenseType.other:     'Other',
};

const _incomeLabels = {
  IncomeSource.tuition: 'Tuition',
  IncomeSource.work:    'Work',
  IncomeSource.gift:    'Gift',
  IncomeSource.other:   'Other',
};

// ── Expense types shown in normal Expense mode (no IOUs, no internal types) ──
const _expenseTypes = [
  ExpenseType.transport,
  ExpenseType.snacks,
  ExpenseType.shopping,
  ExpenseType.fees,
  ExpenseType.other,
];

// ── Income sources shown in Income mode ──────────────────────────────────────
const _incomeSources = [
  IncomeSource.tuition,
  IncomeSource.work,
  IncomeSource.gift,
  IncomeSource.other,
];

class TransactionSheet extends ConsumerStatefulWidget {
  final bool initialIsIncome;
  final bool startAsBorrowLend;
  const TransactionSheet({
    super.key,
    required this.initialIsIncome,
    this.startAsBorrowLend = false,
  });

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  late _TxMode _mode;
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();

  // Income state
  IncomeSource _incSrc = IncomeSource.tuition;

  // Expense state
  ExpenseType _expType = ExpenseType.other;

  // Borrow/Lend state
  bool _isBorrowed = true;  // true = borrowed from someone, false = lent to someone
  bool _isSettled  = false; // already repaid/received back at time of entry

  @override
  void initState() {
    super.initState();
    if (widget.startAsBorrowLend) {
      _mode = _TxMode.borrowLend;
    } else {
      _mode = widget.initialIsIncome ? _TxMode.income : _TxMode.expense;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _modeColor {
    switch (_mode) {
      case _TxMode.income:     return AppColors.successDone;
      case _TxMode.expense:    return AppColors.warningTag;
      case _TxMode.borrowLend: return AppColors.accentPrimary;
    }
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount'),
          backgroundColor: AppColors.errorAlert,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final monthId = ref.read(currentMonthIdProvider);
    final id = const Uuid().v4();
    final note = _noteCtrl.text.trim();
    final now = DateTime.now();

    final Transaction tx;

    switch (_mode) {
      case _TxMode.income:
        tx = Transaction(
          id: id,
          date: now,
          direction: Direction.income,
          amount: amt,
          incomeSource: _incSrc,
          note: note,
          monthId: monthId,
        );
        break;

      case _TxMode.expense:
        tx = Transaction(
          id: id,
          date: now,
          direction: Direction.expense,
          amount: amt,
          expenseType: _expType,
          note: note,
          monthId: monthId,
        );
        break;

      case _TxMode.borrowLend:
        tx = Transaction(
          id: id,
          date: now,
          direction: _isBorrowed ? Direction.income : Direction.expense,
          amount: amt,
          expenseType: _isBorrowed ? ExpenseType.borrowed : ExpenseType.lent,
          note: note,
          isSettled: _isSettled,
          monthId: monthId,
        );
        HapticFeedback.lightImpact();
        await ref.read(walletNotifierProvider.notifier).addTransaction(tx);
        if (_isSettled) {
          await ref.read(walletNotifierProvider.notifier).settleTransaction(tx);
        }
        if (mounted) Navigator.pop(context);
        return;
    }

    HapticFeedback.lightImpact();
    await ref.read(walletNotifierProvider.notifier).addTransaction(tx);
    if (mounted) Navigator.pop(context);
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
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── 3-way mode toggle ─────────────────────────────────────────
            Row(
              children: [
                _ModeTab(
                  label: 'Income',
                  color: AppColors.successDone,
                  active: _mode == _TxMode.income,
                  onTap: () => setState(() => _mode = _TxMode.income),
                ),
                const SizedBox(width: 8),
                _ModeTab(
                  label: 'Expense',
                  color: AppColors.warningTag,
                  active: _mode == _TxMode.expense,
                  onTap: () => setState(() => _mode = _TxMode.expense),
                ),
                const SizedBox(width: 8),
                _ModeTab(
                  label: 'Borrow / Lend',
                  color: AppColors.accentPrimary,
                  active: _mode == _TxMode.borrowLend,
                  onTap: () => setState(() => _mode = _TxMode.borrowLend),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Amount input ──────────────────────────────────────────────
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.displayHeading.copyWith(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: _modeColor,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: AppTypography.displayHeading.copyWith(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPlaceholder,
                ),
                border: InputBorder.none,
                prefixText: '৳ ',
                prefixStyle: AppTypography.displayHeading.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Mode-specific controls ────────────────────────────────────
            if (_mode == _TxMode.income)   _buildIncomeSection(),
            if (_mode == _TxMode.expense)  _buildExpenseSection(),
            if (_mode == _TxMode.borrowLend) _buildBorrowLendSection(),

            const SizedBox(height: 20),

            // ── Note field ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              child: TextField(
                controller: _noteCtrl,
                style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: _mode == _TxMode.borrowLend
                      ? 'Who did you borrow from / lend to?'
                      : 'Add an optional note...',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textPlaceholder, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            ActionButton(
              icon: Icons.check_rounded,
              label: 'Save Transaction',
              isPrimary: true,
              color: _modeColor,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }

  // ── Income category chips ─────────────────────────────────────────────────

  Widget _buildIncomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORY', style: AppTypography.sectionLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _incomeSources.map((src) {
            final label = _incomeLabels[src] ?? src.name;
            final active = _incSrc == src;
            return GestureDetector(
              onTap: () => setState(() => _incSrc = src),
              child: _Chip(label: label, active: active, color: AppColors.successDone),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Expense category chips ────────────────────────────────────────────────

  Widget _buildExpenseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORY', style: AppTypography.sectionLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _expenseTypes.map((type) {
            final label = _expenseLabels[type] ?? type.name;
            final active = _expType == type;
            return GestureDetector(
              onTap: () => setState(() => _expType = type),
              child: _Chip(label: label, active: active, color: AppColors.warningTag),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Borrow/Lend controls ──────────────────────────────────────────────────

  Widget _buildBorrowLendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DIRECTION', style: AppTypography.sectionLabel),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isBorrowed = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isBorrowed
                        ? AppColors.errorAlert.withValues(alpha: 0.12)
                        : AppColors.appBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isBorrowed ? AppColors.errorAlert : Colors.white.withValues(alpha: 0.07),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.call_received_rounded, color: AppColors.errorAlert, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        'Borrowed',
                        style: AppTypography.buttonLabel.copyWith(
                          color: _isBorrowed ? AppColors.errorAlert : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Money came in',
                        style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isBorrowed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !_isBorrowed
                        ? AppColors.accentPrimary.withValues(alpha: 0.12)
                        : AppColors.appBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isBorrowed ? AppColors.accentPrimary : Colors.white.withValues(alpha: 0.07),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.call_made_rounded, color: AppColors.accentPrimary, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        'Lent',
                        style: AppTypography.buttonLabel.copyWith(
                          color: !_isBorrowed ? AppColors.accentPrimary : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Money went out',
                        style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Settled toggle
        GestureDetector(
          onTap: () => setState(() => _isSettled = !_isSettled),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isSettled
                  ? AppColors.successDone.withValues(alpha: 0.08)
                  : AppColors.appBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSettled ? AppColors.successDone.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSettled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: _isSettled ? AppColors.successDone : AppColors.textPlaceholder,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Already settled / repaid',
                  style: AppTypography.bodyText.copyWith(
                    color: _isSettled ? AppColors.successDone : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : AppColors.appBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? color : Colors.white.withValues(alpha: 0.07)),
          ),
          child: Text(
            label,
            style: AppTypography.buttonLabel.copyWith(
              color: active ? color : AppColors.textMuted,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  const _Chip({required this.label, required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : AppColors.appBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.bodyText.copyWith(
          color: active ? color : AppColors.textSecondary,
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
