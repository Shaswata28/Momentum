import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/wallet_providers.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/action_button.dart';

class TransactionSheet extends ConsumerStatefulWidget {
  final bool initialIsIncome;
  const TransactionSheet({super.key, required this.initialIsIncome});

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  late bool _isIncome;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final DateTime _selectedDate = DateTime.now();
  
  ExpenseType? _expType = ExpenseType.variable;
  IncomeSource? _incSrc = IncomeSource.other;
  final bool _isSettled = false;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.initialIsIncome;
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amt <= 0) return;

    final tx = Transaction(
      id: const Uuid().v4(),
      date: _selectedDate,
      direction: _isIncome ? Direction.income : Direction.expense,
      amount: amt,
      expenseType: _isIncome ? null : _expType,
      incomeSource: _isIncome ? _incSrc : null,
      note: _noteCtrl.text.trim(),
      isSettled: (_isIncome || _expType != ExpenseType.borrowed) ? true : _isSettled, 
      monthId: '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}',
    );

    await ref.read(walletNotifierProvider.notifier).addTransaction(tx);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(color: AppColors.appBackground, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardSpace),
      child: SingleChildScrollView(
         child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
               // Segmented Toggle
               Row(
                 children: [
                    Expanded(
                       child: GestureDetector(
                           onTap: () => setState((){ _isIncome=true; }),
                           child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                 color: _isIncome ? AppColors.successDone.withValues(alpha:0.15) : Colors.transparent,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: _isIncome ? AppColors.successDone : const Color(0xFF1E1E2E))
                              ),
                              child: Text('Income', style: AppTypography.buttonLabel.copyWith(color: _isIncome ? AppColors.successDone : AppColors.textMuted))
                           )
                       )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                       child: GestureDetector(
                           onTap: () => setState((){ _isIncome=false; }),
                           child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                 color: !_isIncome ? AppColors.warningTag.withValues(alpha:0.15) : Colors.transparent,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: !_isIncome ? AppColors.warningTag : const Color(0xFF1E1E2E))
                              ),
                              child: Text('Expense', style: AppTypography.buttonLabel.copyWith(color: !_isIncome ? AppColors.warningTag : AppColors.textMuted))
                           )
                       )
                    )
                 ]
               ),
               const SizedBox(height: 32),
               
               // Large Amount Input
               TextField(
                   controller: _amountCtrl,
                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   textAlign: TextAlign.center,
                   style: AppTypography.displayHeading.copyWith(fontSize: 48, color: _isIncome ? AppColors.successDone : AppColors.warningTag),
                   decoration: InputDecoration(
                       hintText: '0.00',
                       hintStyle: AppTypography.displayHeading.copyWith(fontSize: 48, color: AppColors.textMuted.withValues(alpha:0.3)),
                       border: InputBorder.none,
                       prefixText: '৳ ',
                       prefixStyle: AppTypography.displayHeading.copyWith(fontSize: 48, color: AppColors.textSecondary),
                   ),
               ),
               const SizedBox(height: 24),
               
               // Type selector
               Text('TYPE', style: AppTypography.sectionLabel),
               const SizedBox(height: 8),
               Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _isIncome 
                      ? IncomeSource.values.map((s) => ChoiceChip(
                           label: Text(s.name),
                           selected: _incSrc == s,
                           onSelected: (val) => setState(()=> _incSrc = val ? s : _incSrc),
                           backgroundColor: const Color(0xFF121217),
                           selectedColor: AppColors.accentPrimary.withValues(alpha: 0.2),
                           labelStyle: AppTypography.bodyText.copyWith(color: _incSrc == s ? AppColors.accentPrimary : AppColors.textMuted),
                           showCheckmark: false,
                        )).toList()
                      : ExpenseType.values.where((s) => s != ExpenseType.fixed).map((s) => ChoiceChip(
                           label: Text(s.name),
                           selected: _expType == s,
                           onSelected: (val) => setState(()=> _expType = val ? s : _expType),
                           backgroundColor: const Color(0xFF121217),
                           selectedColor: AppColors.accentPrimary.withValues(alpha: 0.2),
                           labelStyle: AppTypography.bodyText.copyWith(color: _expType == s ? AppColors.accentPrimary : AppColors.textMuted),
                           showCheckmark: false,
                        )).toList()
               ),
               const SizedBox(height: 24),
               
               // Note field
               Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFF121217), borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                     controller: _noteCtrl,
                     style: AppTypography.bodyText,
                     decoration: InputDecoration(
                        hintText: 'Add an optional note...',
                        hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                     )
                  )
               ),
               const SizedBox(height: 32),
               
               ActionButton(
                  icon: Icons.check,
                  label: 'SAVE TRANSACTION',
                  color: AppColors.accentPrimary,
                  onTap: _save,
               )
            ]
         )
      )
    );
  }
}
