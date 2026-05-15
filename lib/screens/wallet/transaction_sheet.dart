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

  // ── Color helpers ───────────────────────────────────────────────────────────

  Color get _modeColor {
    switch (_mode) {
      case _TxMode.income:     return AppColors.successDone;
      case _TxMode.expense:    return AppColors.warningTag;
      case _TxMode.borrowLend: return AppColors.accentPrimary;
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amt <= 0) return;

    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    Transaction tx;

    switch (_mode) {
      case _TxMode.income:
        tx = Transaction(
          id: const Uuid().v4(),
          date: now,
          direction: Direction.income,
          amount: amt,
          incomeSource: _incSrc,
          note: _noteCtrl.text.trim(),
          isSettled: true,
          monthId: monthId,
        );

      case _TxMode.expense:
        tx = Transaction(
          id: const Uuid().v4(),
          date: now,
          direction: Direction.expense,
          amount: amt,
          expenseType: _expType,
          note: _noteCtrl.text.trim(),
          isSettled: true,
          monthId: monthId,
        );

      case _TxMode.borrowLend:
        tx = Transaction(
          id: const Uuid().v4(),
          date: now,
          // Borrowed (received) uses Direction.income so prefix is + in row
          // Lent (given out) uses Direction.expense so prefix is -
          direction: _isBorrowed ? Direction.income : Direction.expense,
          amount: amt,
          expenseType: _isBorrowed ? ExpenseType.borrowed : ExpenseType.lent,
          note: _noteCtrl.text.trim(),
          isSettled: _isSettled,
          monthId: monthId,
        );
    }

    await ref.read(walletNotifierProvider.notifier).addTransaction(tx);
    if (mounted) Navigator.pop(context);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

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
                  label: 'Borrow/Lend',
                  color: AppColors.accentPrimary,
                  active: _mode == _TxMode.borrowLend,
                  onTap: () => setState(() => _mode = _TxMode.borrowLend),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Amount input ──────────────────────────────────────────────
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.displayHeading.copyWith(
                fontSize: 48,
                color: _modeColor,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: AppTypography.displayHeading.copyWith(
                  fontSize: 48,
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                prefixText: '৳ ',
                prefixStyle: AppTypography.displayHeading.copyWith(
                  fontSize: 48,
                  color: AppColors.textSecondary,
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
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _noteCtrl,
                style: AppTypography.bodyText,
                decoration: InputDecoration(
                  hintText: _mode == _TxMode.borrowLend
                      ? 'Who did you borrow from / lend to?'
                      : 'Add an optional note...',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 28),

            ActionButton(
              icon: Icons.check,
              label: 'SAVE TRANSACTION',
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
        Text('TYPE', style: AppTypography.sectionLabel),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isBorrowed = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _isBorrowed
                        ? AppColors.errorAlert.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isBorrowed ? AppColors.errorAlert : const Color(0xFF1E1E2E),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Borrowed',
                        style: AppTypography.buttonLabel.copyWith(
                          color: _isBorrowed ? AppColors.errorAlert : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'money came in',
                        style: AppTypography.sectionLabel.copyWith(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isBorrowed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: !_isBorrowed
                        ? AppColors.accentPrimary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !_isBorrowed ? AppColors.accentPrimary : const Color(0xFF1E1E2E),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Lent',
                        style: AppTypography.buttonLabel.copyWith(
                          color: !_isBorrowed ? AppColors.accentPrimary : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'money went out',
                        style: AppTypography.sectionLabel.copyWith(fontSize: 9),
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
                  : const Color(0xFF121217),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSettled ? AppColors.successDone.withValues(alpha: 0.4) : const Color(0xFF1E1E2E),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSettled ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _isSettled ? AppColors.successDone : AppColors.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  'Already settled / paid back',
                  style: AppTypography.bodyText.copyWith(
                    color: _isSettled ? AppColors.successDone : AppColors.textSecondary,
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
            color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color : const Color(0xFF1E1E2E)),
          ),
          child: Text(
            label,
            style: AppTypography.buttonLabel.copyWith(
              color: active ? color : AppColors.textMuted,
              fontSize: 12,
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
        color: active ? color.withValues(alpha: 0.15) : const Color(0xFF121217),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.6) : const Color(0xFF1E1E2E),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.bodyText.copyWith(
          color: active ? color : AppColors.textMuted,
          fontSize: 13,
        ),
      ),
    );
  }
}
