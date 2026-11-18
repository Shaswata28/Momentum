import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../repositories/wallet_repository.dart';
import '../../providers/wallet_providers.dart';
import '../../models/transaction.dart';
import '../../models/category_meta.dart';
import '../../models/category_inference.dart';
import '../../theme/app_colors.dart';
import '../../theme/retro_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../widgets/action_button.dart';

// ── Mode enum ─────────────────────────────────────────────────────────────────
enum _TxMode { income, expense, borrowLend }

class TransactionSheet extends ConsumerStatefulWidget {
  final bool initialIsIncome;
  final bool startAsBorrowLend;
  final String? visibleMonthId;
  final Transaction? transactionToEdit;
  const TransactionSheet({
    super.key,
    required this.initialIsIncome,
    this.startAsBorrowLend = false,
    this.visibleMonthId,
    this.transactionToEdit,
  });

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  late _TxMode _mode;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late DateTime _date;
  bool _saving = false;
  String? _error;
  late final String _transactionId;
  Transaction? _savedEntry;

  // Income state
  IncomeSource _incSrc = IncomeSource.salary;

  // Expense state
  ExpenseType _expType = ExpenseType.transport;

  // Category expansion state
  bool _categoriesExpanded = false;

  // Borrow/Lend state
  bool _isBorrowed =
      true; // true = borrowed from someone, false = lent to someone
  bool _isSettled = false; // already repaid/received back at time of entry

  @override
  void initState() {
    super.initState();
    final editTx = widget.transactionToEdit;
    if (editTx != null) {
      _transactionId = editTx.id;
      _date = DateUtils.dateOnly(editTx.date);
      if (editTx.amount == editTx.amount.roundToDouble()) {
        _amountCtrl.text = editTx.amount.toInt().toString();
      } else {
        _amountCtrl.text = editTx.amount.toString();
      }
      _noteCtrl.text = editTx.note;

      final isIou = editTx.expenseType == ExpenseType.borrowed ||
          editTx.expenseType == ExpenseType.lent;
      if (isIou) {
        _mode = _TxMode.borrowLend;
        _isBorrowed = editTx.expenseType == ExpenseType.borrowed;
        _isSettled = editTx.isSettled;
      } else if (editTx.direction == Direction.income) {
        _mode = _TxMode.income;
        _incSrc = editTx.incomeSource ?? IncomeSource.salary;
      } else {
        _mode = _TxMode.expense;
        _expType = editTx.expenseType ?? ExpenseType.transport;
      }
    } else {
      _transactionId = const Uuid().v4();
      _date = DateUtils.dateOnly(DateTime.now());
      if (widget.startAsBorrowLend) {
        _mode = _TxMode.borrowLend;
      } else {
        _mode = widget.initialIsIncome ? _TxMode.income : _TxMode.expense;
      }
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
      case _TxMode.income:
        return AppColors.successDone;
      case _TxMode.expense:
        return AppColors.errorAlert;
      case _TxMode.borrowLend:
        return AppColors.accentPrimary;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || !amt.isFinite || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount'),
          backgroundColor: AppColors.errorAlert,
        ),
      );
      return;
    }

    final monthId = WalletRepository.monthIdForDate(_date);
    final id = _transactionId;
    final note = _noteCtrl.text.trim();
    final now = _date;
    final isEditing = widget.transactionToEdit != null;
    setState(() {
      _saving = true;
      _error = null;
    });

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
          isSettled: isEditing ? _isSettled : false,
          monthId: monthId,
        );
        break;
    }

    try {
      final notifier = ref.read(walletNotifierProvider.notifier);
      if (isEditing) {
        await notifier.addTransaction(tx);
      } else {
        if (_savedEntry == null) {
          await notifier.addTransaction(tx);
          _savedEntry = tx;
        }
        if (_mode == _TxMode.borrowLend && _isSettled) {
          await notifier.settleTransaction(_savedEntry!);
        }
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Transaction updated'
                : 'Recorded ${DateFormat.yMMMd().format(_date)} (${DateFormat.yMMMM().format(_date)})',
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not save. Your inputs are kept. Please retry.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final isRetro = AppColors.isRetro;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isRetro
              ? AppColors.cardBorder
              : Colors.white.withValues(alpha: 0.08),
          width: isRetro ? 2.0 : 1.0,
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + keyboardSpace),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnorePointer(
              ignoring: _saving || _savedEntry != null,
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
                        color: isRetro
                            ? AppColors.cardBorder
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: isRetro
                            ? BorderRadius.zero
                            : BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  if (widget.transactionToEdit != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: AppColors.accentPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isRetro ? 'EDIT TRANSACTION' : 'Edit Transaction',
                          style: isRetro
                              ? RetroTypography.sectionLabel.copyWith(
                                  fontSize: 10,
                                  color: AppColors.accentPrimary,
                                )
                              : AppTypography.tagChip.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentPrimary,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 3-way mode toggle ─────────────────────────────────────────
                  Row(
                    children: [
                      _ModeTab(
                        label: 'Income',
                        color: AppColors.successDone,
                        active: _mode == _TxMode.income,
                        onTap: () => setState(() {
                          _mode = _TxMode.income;
                          _categoriesExpanded = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _ModeTab(
                        label: 'Expense',
                        color: AppColors.errorAlert,
                        active: _mode == _TxMode.expense,
                        onTap: () => setState(() {
                          _mode = _TxMode.expense;
                          _categoriesExpanded = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _ModeTab(
                        label: 'Borrow / Lend',
                        color: AppColors.accentPrimary,
                        active: _mode == _TxMode.borrowLend,
                        onTap: () => setState(() {
                          _mode = _TxMode.borrowLend;
                          _categoriesExpanded = false;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Date chip ─────────────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _saving
                          ? null
                          : () async {
                              final today = DateUtils.dateOnly(DateTime.now());
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _date.isAfter(today) ? today : _date,
                                firstDate: DateTime(1),
                                lastDate: today,
                                helpText: 'Transaction date (today or earlier)',
                              );
                              if (picked != null && mounted) {
                                setState(() => _date = picked);
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isRetro
                              ? AppColors.inputBackground
                              : AppColors.appBackground,
                          borderRadius: isRetro
                              ? BorderRadius.zero
                              : BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: isRetro ? 1.5 : 1.0,
                          ),
                          boxShadow: isRetro
                              ? [
                                  BoxShadow(
                                    color: AppColors.retroShadowColor,
                                    offset: const Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: isRetro
                                  ? AppColors.accentPrimary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Date: ${DateFormat.yMMMd().format(_date)}',
                              style: isRetro
                                  ? RetroTypography.bodyText.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 11,
                                    )
                                  : AppTypography.bodyText.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.visibleMonthId != null &&
                      widget.visibleMonthId !=
                          WalletRepository.monthIdForDate(_date))
                    Text(
                      'This entry belongs to ${DateFormat.yMMMM().format(_date)}, outside the month you are viewing. Your browsing month will stay unchanged.',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.warningTag,
                      ),
                    ),
                  const SizedBox(height: 12),

                  // ── Amount input ──────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isRetro ? AppColors.inputBackground : null,
                      borderRadius: isRetro ? BorderRadius.zero : null,
                      border: isRetro
                          ? Border.all(color: _modeColor, width: 2.0)
                          : null,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isRetro ? 6 : 0,
                      horizontal: isRetro ? 12 : 0,
                    ),
                    child: TextField(
                      controller: _amountCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.amountLarge.copyWith(
                        fontSize: isRetro ? 38 : 44,
                        fontWeight: FontWeight.w700,
                        color: _modeColor,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: '0.00',
                        hintStyle: AppTypography.amountLarge.copyWith(
                          fontSize: isRetro ? 38 : 44,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPlaceholder,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        prefixText: '৳ ',
                        prefixStyle: AppTypography.amountLarge.copyWith(
                          fontSize: isRetro ? 28 : 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Mode-specific controls ────────────────────────────────────
                  if (_mode == _TxMode.income) _buildIncomeSection(),
                  if (_mode == _TxMode.expense) _buildExpenseSection(),
                  if (_mode == _TxMode.borrowLend) _buildBorrowLendSection(),

                  const SizedBox(height: 20),

                  // ── Note field ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isRetro
                          ? AppColors.inputBackground
                          : AppColors.appBackground,
                      borderRadius: isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: isRetro ? 1.5 : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _noteCtrl,
                      onChanged: (text) {
                        if (_mode == _TxMode.expense) {
                          final inferred = CategoryInference.inferExpense(text);
                          if (inferred != null && inferred != _expType) {
                            HapticFeedback.selectionClick();
                            setState(() => _expType = inferred);
                          }
                        } else if (_mode == _TxMode.income) {
                          final inferred = CategoryInference.inferIncome(text);
                          if (inferred != null && inferred != _incSrc) {
                            HapticFeedback.selectionClick();
                            setState(() => _incSrc = inferred);
                          }
                        }
                      },
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: _mode == _TxMode.borrowLend
                            ? 'Who did you borrow from / lend to?'
                            : 'Add an optional note...',
                        hintStyle: AppTypography.bodyText.copyWith(
                          color: AppColors.textPlaceholder,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.errorAlert,
                ),
              ),
            ActionButton(
              icon: Icons.check_rounded,
              label: _saving
                  ? (widget.transactionToEdit != null
                      ? 'Updating...'
                      : 'Saving...')
                  : (widget.transactionToEdit != null
                      ? 'Update Transaction'
                      : 'Save Transaction'),
              isLoading: _saving,
              isPrimary: true,
              color: _modeColor,
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Header & Controls ──────────────────────────────────────────

  Widget _buildCategoryHeader() {
    final isRetro = AppColors.isRetro;
    return Text(
      'CATEGORY',
      style: isRetro
          ? RetroTypography.sectionLabel.copyWith(fontSize: 9)
          : AppTypography.sectionLabel,
    );
  }

  Widget _buildSelectedCategoryBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isRetro = AppColors.isRetro;
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _categoriesExpanded = !_categoriesExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: isRetro ? 12 : 14,
          vertical: isRetro ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isRetro
              ? AppColors.inputBackground
              : color.withValues(
                  alpha: isDark ? 0.18 : 0.14,
                ),
          borderRadius:
              isRetro ? BorderRadius.zero : BorderRadius.circular(12),
          border: Border.all(
            color: isRetro ? AppColors.cardBorder : color.withValues(alpha: 0.6),
            width: isRetro ? 2.0 : 1.5,
          ),
          boxShadow: isRetro
              ? [
                  BoxShadow(
                    color: AppColors.retroShadowColor,
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isRetro ? 28 : 28,
              height: isRetro ? 28 : 28,
              decoration: BoxDecoration(
                color: isRetro ? color : color.withValues(alpha: 0.2),
                borderRadius:
                    isRetro ? BorderRadius.zero : BorderRadius.circular(8),
                border: isRetro
                    ? Border.all(color: AppColors.cardBorder, width: 1.5)
                    : null,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isRetro ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: isRetro
                  ? RetroTypography.cardTitle.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? AppColors.textPrimary : RetroLightColors.ink,
                    )
                  : AppTypography.cardTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
            ),
            const SizedBox(width: 8),
            Icon(
              _categoriesExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isRetro
                  ? (isDark ? AppColors.textPrimary : RetroLightColors.ink)
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ── Income category chips ─────────────────────────────────────────────────

  Widget _buildIncomeSection() {
    final meta = CategoryMeta.forIncome(_incSrc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryHeader(),
        const SizedBox(height: 10),
        _buildSelectedCategoryBadge(
          label: meta.label,
          icon: meta.iconFill,
          color: meta.color,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _categoriesExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryMeta.visibleIncomeSources.map((src) {
                      final itemMeta = CategoryMeta.forIncome(src);
                      final active = _incSrc == src;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _incSrc = src;
                            _categoriesExpanded = false;
                          });
                        },
                        child: _Chip(
                          label: itemMeta.label,
                          icon: active ? itemMeta.iconFill : itemMeta.icon,
                          active: active,
                          color: itemMeta.color,
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Expense category chips ────────────────────────────────────────────────

  Widget _buildExpenseSection() {
    final meta = CategoryMeta.forExpense(_expType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryHeader(),
        const SizedBox(height: 10),
        _buildSelectedCategoryBadge(
          label: meta.label,
          icon: meta.iconFill,
          color: meta.color,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _categoriesExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryMeta.visibleExpenseTypes.map((type) {
                      final itemMeta = CategoryMeta.forExpense(type);
                      final active = _expType == type;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _expType = type;
                            _categoriesExpanded = false;
                          });
                        },
                        child: _Chip(
                          label: itemMeta.label,
                          icon: active ? itemMeta.iconFill : itemMeta.icon,
                          active: active,
                          color: itemMeta.color,
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Borrow/Lend controls ──────────────────────────────────────────────────

  Widget _buildBorrowLendSection() {
    final isRetro = AppColors.isRetro;
    final isDark = AppColors.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIRECTION',
          style: isRetro
              ? RetroTypography.sectionLabel.copyWith(fontSize: 9)
              : AppTypography.sectionLabel,
        ),
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
                        ? (isRetro
                            ? AppColors.errorAlert
                            : AppColors.errorAlert.withValues(alpha: 0.12))
                        : (isRetro
                            ? AppColors.inputBackground
                            : AppColors.appBackground),
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    border: Border.all(
                      color: isRetro
                          ? AppColors.cardBorder
                          : (_isBorrowed
                              ? AppColors.errorAlert
                              : Colors.white.withValues(alpha: 0.07)),
                      width: isRetro ? 2.0 : 1.5,
                    ),
                    boxShadow: (isRetro && _isBorrowed)
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsRegular.arrowDown,
                        color: _isBorrowed && isRetro
                            ? Colors.white
                            : AppColors.errorAlert,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Borrowed',
                        style: isRetro
                            ? RetroTypography.buttonLabel.copyWith(
                                color: _isBorrowed
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textPrimary
                                        : RetroLightColors.ink),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              )
                            : AppTypography.buttonLabel.copyWith(
                                color: _isBorrowed
                                    ? AppColors.errorAlert
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Money came in',
                        style: isRetro
                            ? RetroTypography.bodyText.copyWith(
                                color: _isBorrowed
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.textMuted,
                                fontSize: 9.5,
                              )
                            : AppTypography.bodyText.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
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
                        ? (isRetro
                            ? AppColors.accentPrimary
                            : AppColors.accentPrimary.withValues(alpha: 0.12))
                        : (isRetro
                            ? AppColors.inputBackground
                            : AppColors.appBackground),
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    border: Border.all(
                      color: isRetro
                          ? AppColors.cardBorder
                          : (!_isBorrowed
                              ? AppColors.accentPrimary
                              : Colors.white.withValues(alpha: 0.07)),
                      width: isRetro ? 2.0 : 1.5,
                    ),
                    boxShadow: (isRetro && !_isBorrowed)
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsRegular.arrowUp,
                        color: !_isBorrowed && isRetro
                            ? Colors.white
                            : AppColors.accentPrimary,
                        size: 20,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lent',
                        style: isRetro
                            ? RetroTypography.buttonLabel.copyWith(
                                color: !_isBorrowed
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.textPrimary
                                        : RetroLightColors.ink),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              )
                            : AppTypography.buttonLabel.copyWith(
                                color: !_isBorrowed
                                    ? AppColors.accentPrimary
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Money went out',
                        style: isRetro
                            ? RetroTypography.bodyText.copyWith(
                                color: !_isBorrowed
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.textMuted,
                                fontSize: 9.5,
                              )
                            : AppTypography.bodyText.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
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
                color: _isSettled
                    ? AppColors.successDone.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSettled
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: _isSettled
                      ? AppColors.successDone
                      : AppColors.textPlaceholder,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settle today (repayment dated today)',
                    style: AppTypography.bodyText.copyWith(
                      color: _isSettled
                          ? AppColors.successDone
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
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
  const _ModeTab({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final isDark = AppColors.isDark;
    final fgColor = active
        ? (isRetro
            ? (isDark ? const Color(0xFF141418) : Colors.white)
            : color)
        : (isRetro
            ? (isDark ? AppColors.textSecondary : RetroLightColors.ink)
            : AppColors.textMuted);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          constraints: const BoxConstraints(minHeight: 48),
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: isRetro ? 8 : 10,
            horizontal: 4,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? (isRetro
                    ? color
                    : color.withValues(
                        alpha: isDark ? 0.20 : 0.14,
                      ))
                : (isRetro
                    ? AppColors.inputBackground
                    : AppColors.appBackground),
            borderRadius: isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(10),
            border: Border.all(
              color: isRetro
                  ? AppColors.cardBorder
                  : (active ? color : Colors.white.withValues(alpha: 0.07)),
              width: isRetro ? 2.0 : 1.0,
            ),
            boxShadow: (isRetro && active)
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: isRetro
                ? RetroTypography.buttonLabel.copyWith(
                    color: fgColor,
                    fontSize: 9.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  )
                : AppTypography.buttonLabel.copyWith(
                    color: fgColor,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;

  const _Chip({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final isDark = AppColors.isDark;

    final chipBg = active
        ? (isRetro
            ? color
            : color.withValues(alpha: isDark ? 0.20 : 0.14))
        : (isRetro ? AppColors.inputBackground : AppColors.appBackground);

    final chipFg = active
        ? (isRetro
            ? (isDark ? const Color(0xFF141418) : Colors.white)
            : color)
        : (isRetro
            ? (isDark ? AppColors.textPrimary : RetroLightColors.ink)
            : AppColors.textSecondary);

    final iconColor = active
        ? (isRetro
            ? (isDark ? const Color(0xFF141418) : Colors.white)
            : color)
        : (isRetro ? color : color.withValues(alpha: 0.75));

    return AnimatedContainer(
      constraints: const BoxConstraints(minHeight: 38),
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
        border: Border.all(
          color: isRetro
              ? AppColors.cardBorder
              : (active
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08)),
          width: isRetro ? 2.0 : 1.0,
        ),
        boxShadow: (isRetro && active)
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    color: chipFg,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  )
                : AppTypography.bodyText.copyWith(
                    color: chipFg,
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
          ),
        ],
      ),
    );
  }
}
