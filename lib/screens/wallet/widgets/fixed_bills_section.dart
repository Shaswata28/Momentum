import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../models/fixed_expense.dart';
import '../../../providers/wallet_providers.dart';
import '../../../widgets/action_button.dart';

PhosphorIconData _resolveBillIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('wifi') ||
      lower.contains('internet') ||
      lower.contains('broadband') ||
      lower.contains('net')) {
    return PhosphorIconsRegular.wifiHigh;
  }
  if (lower.contains('rent') ||
      lower.contains('house') ||
      lower.contains('flat') ||
      lower.contains('room') ||
      lower.contains('mess') ||
      lower.contains('hostel') ||
      lower.contains('bari')) {
    return PhosphorIconsRegular.house;
  }
  if (lower.contains('electric') ||
      lower.contains('power') ||
      lower.contains('desco') ||
      lower.contains('dpdc') ||
      lower.contains('nesco') ||
      lower.contains('current') ||
      lower.contains('utility')) {
    return PhosphorIconsRegular.lightning;
  }
  if (lower.contains('phone') ||
      lower.contains('mobile') ||
      lower.contains('recharge') ||
      lower.contains('gp') ||
      lower.contains('robi') ||
      lower.contains('banglalink') ||
      lower.contains('airtel') ||
      lower.contains('flexi')) {
    return PhosphorIconsRegular.deviceMobile;
  }
  if (lower.contains('netflix') ||
      lower.contains('prime') ||
      lower.contains('movie') ||
      lower.contains('tv') ||
      lower.contains('chorki') ||
      lower.contains('hoichoi') ||
      lower.contains('stream') ||
      lower.contains('spotify') ||
      lower.contains('music') ||
      lower.contains('youtube')) {
    return PhosphorIconsRegular.popcorn;
  }
  if (lower.contains('tuition') ||
      lower.contains('school') ||
      lower.contains('college') ||
      lower.contains('uni') ||
      lower.contains('course') ||
      lower.contains('coaching')) {
    return PhosphorIconsRegular.bookOpen;
  }
  return PhosphorIconsRegular.receipt;
}

class FixedBillsSection extends ConsumerWidget {
  const FixedBillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixedExpenses = ref.watch(fixedExpensesProvider);
    final monthId = ref.watch(currentMonthIdProvider);
    final isRetro = AppColors.isRetro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text('FIXED BILLS', style: AppTypography.sectionLabel),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showAddSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(
                    alpha: isRetro ? 0.2 : 0.12,
                  ),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: isRetro ? 1.5 : 1.0,
                  ),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      semanticLabel: 'Add recurring bill',
                      color: AppColors.accentPrimary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: AppTypography.buttonLabel.copyWith(
                        color: AppColors.accentPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Empty state or Bill List ────────────────────────────────
        if (fixedExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cardBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: AppColors.textPlaceholder,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  'No recurring bills',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cardBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: fixedExpenses.asMap().entries.map((entry) {
                final isLast = entry.key == fixedExpenses.length - 1;
                return _BillRow(
                  expense: entry.value,
                  monthId: monthId,
                  isLast: isLast,
                  onMarkPaid: () =>
                      _markPaid(context, ref, entry.value, monthId),
                  onDelete: () => ref
                      .read(walletNotifierProvider.notifier)
                      .deleteFixedExpense(entry.value.id),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    FixedExpense expense,
    String currentMonthId,
  ) async {
    await ref.read(walletNotifierProvider.notifier).payFixedExpense(expense);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Paid ${expense.name} for $currentMonthId'),
              ),
            ],
          ),
          backgroundColor: AppColors.successDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(milliseconds: 2000),
        ),
      );
    }
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: AppColors.isRetro
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      builder: (_) => _AddBillSheet(ref: ref),
    );
  }
}

// ── Individual bill row ───────────────────────────────────────────────────────

class _BillRow extends StatefulWidget {
  final FixedExpense expense;
  final String monthId;
  final bool isLast;
  final Future<void> Function() onMarkPaid;
  final Future<void> Function() onDelete;

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

  Future<void> _handlePay() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onMarkPaid();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pay bill. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.expense.lastPaidMonthKey == widget.monthId;
    final isRetro = AppColors.isRetro;
    final formattedAmt = widget.expense.amount % 1 == 0
        ? '৳${NumberFormat('#,##0').format(widget.expense.amount)}'
        : currencyFormat.format(widget.expense.amount);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showDeleteDialog(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: widget.isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category Icon Badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isPaid
                        ? AppColors.successDone
                        : AppColors.accentPrimary)
                    .withValues(
                  alpha: isRetro ? 0.2 : 0.12,
                ),
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(10),
                border: isRetro
                    ? Border.all(color: AppColors.cardBorder, width: 1.5)
                    : null,
              ),
              child: Icon(
                _resolveBillIcon(widget.expense.name),
                color: isPaid
                    ? AppColors.successDone
                    : AppColors.accentPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // Name + due date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.expense.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyText.copyWith(
                      color:
                          isPaid ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: isPaid ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due ${_ordinal(widget.expense.billingDay)} of month',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount + Action
            if (isPaid)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedAmt,
                    style: AppTypography.scoreStat.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.successDone,
                    size: 18,
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedAmt,
                    style: AppTypography.scoreStat.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isProcessing ? null : _handlePay,
                    child: AnimatedScale(
                      scale: _isProcessing ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _isProcessing
                              ? AppColors.successDone
                              : AppColors.accentPrimary.withValues(
                                  alpha: isRetro ? 0.2 : 0.12,
                                ),
                          borderRadius: isRetro
                              ? BorderRadius.zero
                              : BorderRadius.circular(6),
                          border: Border.all(
                            color: _isProcessing
                                ? AppColors.successDone
                                : (isRetro
                                    ? AppColors.cardBorder
                                    : AppColors.accentPrimary
                                        .withValues(alpha: 0.3)),
                            width: isRetro ? 1.5 : 1.0,
                          ),
                          boxShadow: (isRetro && !_isProcessing)
                              ? [
                                  BoxShadow(
                                    color: AppColors.retroShadowColor,
                                    offset: const Offset(1.5, 1.5),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          _isProcessing ? 'Saving...' : 'Pay today',
                          style: AppTypography.buttonLabel.copyWith(
                            color: _isProcessing
                                ? Colors.white
                                : AppColors.accentPrimary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
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
    final isRetro = AppColors.isRetro;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius:
              isRetro ? BorderRadius.zero : BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.cardBorder,
            width: isRetro ? 2.0 : 1.0,
          ),
        ),
        title: Text('Remove Bill?', style: AppTypography.headline),
        content: Text(
          'Remove "${widget.expense.name}" from recurring bills?',
          style: AppTypography.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_isProcessing) return;
              setState(() => _isProcessing = true);
              try {
                await widget.onDelete();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not remove bill. Please retry.'),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: Text(
              'Remove',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.errorAlert,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
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
  final _billId = const Uuid().v4();
  bool _saving = false;
  String? _error;
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

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final day = int.tryParse(_dayCtrl.text.trim()) ?? 0;
    if (name.isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        day < 1 ||
        day > 31) {
      setState(
        () => _error =
            'Enter a bill name, a positive amount and a day from 1 to 31.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final expense = FixedExpense(
      id: _billId,
      name: name,
      amount: amount,
      billingDay: day,
    );
    try {
      await widget.ref
          .read(walletNotifierProvider.notifier)
          .addFixedExpense(expense);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save bill. Please retry.');
      }
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
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: isRetro
            ? Border.all(color: AppColors.cardBorder, width: 2.0)
            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + keyboardSpace),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
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
            Text(
              'New Recurring Bill',
              style: isRetro
                  ? AppTypography.titleLarge.copyWith(fontSize: 16)
                  : AppTypography.titleLarge,
            ),
            const SizedBox(height: 16),

            // Name
            Text('BILL NAME', style: AppTypography.sectionLabel),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
              ),
              child: TextField(
                controller: _nameCtrl,
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'e.g. Internet, Rent, Spotify',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            Text('AMOUNT', style: AppTypography.sectionLabel),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
              ),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.scoreStat.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: AppTypography.scoreStat.copyWith(
                    color: AppColors.textPlaceholder,
                  ),
                  prefixText: '৳ ',
                  prefixStyle: AppTypography.scoreStat.copyWith(
                    color: AppColors.accentPrimary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Billing Day
            Text('DUE DAY OF MONTH', style: AppTypography.sectionLabel),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
              ),
              child: TextField(
                controller: _dayCtrl,
                keyboardType: TextInputType.number,
                style: AppTypography.scoreStat.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'Day (1–31)',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Text(
                _error!,
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.errorAlert,
                ),
              ),
              const SizedBox(height: 10),
            ],
            ActionButton(
              icon: Icons.check_rounded,
              label: _saving ? 'Saving...' : 'Add Bill',
              isLoading: _saving,
              isPrimary: true,
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
