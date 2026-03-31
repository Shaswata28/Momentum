import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/wallet_providers.dart';
import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'action_button.dart';

class WalletSummaryCard extends ConsumerStatefulWidget {
  const WalletSummaryCard({super.key});

  @override
  ConsumerState<WalletSummaryCard> createState() => _WalletSummaryCardState();
}

class _WalletSummaryCardState extends ConsumerState<WalletSummaryCard> {
  bool _isExpanded = false;
  bool _isIncome = true;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  
  Color _flashColor = AppColors.textPrimary;
  double _balanceScale = 1.0;

  void _toggle(bool income) {
    setState(() {
      if (_isExpanded && _isIncome == income) {
        _isExpanded = false;
        FocusScope.of(context).unfocus();
      } else {
        _isExpanded = true;
        _isIncome = income;
      }
    });
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amt <= 0) return;
    
    final tx = Transaction(
      id: const Uuid().v4(),
      date: DateTime.now(),
      direction: _isIncome ? Direction.income : Direction.expense,
      amount: amt,
      note: _noteCtrl.text.trim(),
      monthId: ref.read(currentMonthIdProvider),
    );
    
    await ref.read(walletNotifierProvider.notifier).addTransaction(tx);
    
    final wasIncome = _isIncome;
    setState(() {
      _isExpanded = false;
      _flashColor = wasIncome ? AppColors.successDone : AppColors.dangerOverdue;
      _balanceScale = 1.08;
      // Delay clearing text fields slightly so the collapse animation looks smooth
      // without text vanishing instantly.
    });
    FocusScope.of(context).unfocus();
    
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _amountCtrl.clear();
        _noteCtrl.clear();
      }
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _flashColor = AppColors.textPrimary;
          _balanceScale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(runningBalanceProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        border: Border.all(color: const Color(0xFF1A1A24)),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF2A5080)),
                      const SizedBox(width: 8),
                      Text('WALLET BALANCE', style: AppTypography.sectionLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedScale(
                    scale: _balanceScale,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    alignment: Alignment.centerLeft,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      style: AppTypography.scoreStat.copyWith(color: _flashColor, fontSize: 24),
                      child: Text(currencyFormat.format(balance)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                   ActionButton(
                     icon: Icons.add,
                     label: 'In',
                     color: AppColors.successDone,
                     onTap: () => _toggle(true),
                   ),
                   const SizedBox(width: 8),
                   ActionButton(
                     icon: Icons.remove,
                     label: 'Out',
                     color: AppColors.warningTag,
                     onTap: () => _toggle(false),
                   ),
                ],
              )
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: !_isExpanded ? const SizedBox() : Container(
               margin: const EdgeInsets.only(top: 16),
               padding: const EdgeInsets.only(top: 16),
               decoration: const BoxDecoration(
                 border: Border(top: BorderSide(color: Color(0xFF1A1A24))),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   Row(
                     children: [
                       Expanded(
                         child: TextField(
                           controller: _amountCtrl,
                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
                           style: AppTypography.scoreStat.copyWith(color: _isIncome ? AppColors.successDone : AppColors.warningTag),
                           decoration: InputDecoration(
                             hintText: '0.00',
                             hintStyle: AppTypography.scoreStat.copyWith(color: AppColors.textMuted),
                             border: InputBorder.none,
                             prefixText: '৳ ',
                             prefixStyle: AppTypography.scoreStat.copyWith(color: AppColors.textMuted),
                           ),
                         ),
                       ),
                       Container(
                         height: 32,
                         width: 1,
                         color: const Color(0xFF1A1A24),
                         margin: const EdgeInsets.symmetric(horizontal: 12),
                       ),
                       Expanded(
                         flex: 2,
                         child: TextField(
                           controller: _noteCtrl,
                           style: AppTypography.bodyText,
                           decoration: InputDecoration(
                             hintText: 'What was it for?',
                             hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
                             border: InputBorder.none,
                           ),
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   Align(
                     alignment: Alignment.centerRight,
                     child: TextButton(
                       onPressed: _save,
                       style: TextButton.styleFrom(
                         backgroundColor: _isIncome ? AppColors.successDone.withValues(alpha: 0.1) : AppColors.warningTag.withValues(alpha: 0.1),
                         foregroundColor: _isIncome ? AppColors.successDone : AppColors.warningTag,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       ),
                       child: Text('Add ${_isIncome ? 'Income' : 'Expense'}', style: AppTypography.buttonLabel),
                     ),
                   )
                 ],
               ),
            ),
          )
        ],
      ),
    );
  }
}
