import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../models/wallet_settings.dart';
import '../../../models/month_summary.dart';
import '../../../providers/wallet_providers.dart';

class WalletSettingsSheet extends ConsumerStatefulWidget {
  const WalletSettingsSheet({super.key});

  @override
  ConsumerState<WalletSettingsSheet> createState() =>
      _WalletSettingsSheetState();
}

class _WalletSettingsSheetState extends ConsumerState<WalletSettingsSheet> {
  late final TextEditingController _openingCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _goalCtrl;

  @override
  void initState() {
    super.initState();
    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings =
        settingsBox.isEmpty ? WalletSettings() : settingsBox.getAt(0)!;

    final monthId = _currentMonthId();
    final summaryBox = Hive.box<MonthSummary>('monthSummaries');
    final summary = summaryBox.get(monthId);

    _openingCtrl = TextEditingController(
      text: summary?.openingBalance != null && summary!.openingBalance > 0
          ? summary.openingBalance.toStringAsFixed(2)
          : '',
    );
    _budgetCtrl = TextEditingController(
      text: settings.monthlyBudget > 0
          ? settings.monthlyBudget.toStringAsFixed(2)
          : '',
    );
    _goalCtrl = TextEditingController(
      text: settings.semesterGoal > 0
          ? settings.semesterGoal.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    _budgetCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  String _currentMonthId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();

    final opening = double.tryParse(_openingCtrl.text) ?? 0.0;
    final budget  = double.tryParse(_budgetCtrl.text)  ?? 0.0;
    final goal    = double.tryParse(_goalCtrl.text)    ?? 0.0;

    // 1. Save WalletSettings (budget + savings goal — global across months)
    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final updated = WalletSettings(
      initialBalance: opening,
      monthlyBudget: budget,
      semesterGoal: goal,
    );
    if (settingsBox.isEmpty) {
      await settingsBox.add(updated);
    } else {
      await settingsBox.putAt(0, updated);
    }

    // 2. Save opening balance into this month's MonthSummary
    final monthId    = _currentMonthId();
    final summaryBox = Hive.box<MonthSummary>('monthSummaries');
    final existing   = summaryBox.get(monthId);
    final newSummary = MonthSummary(
      id: monthId,
      openingBalance: opening,
      totalIncome: existing?.totalIncome ?? 0,
      totalExpense: existing?.totalExpense ?? 0,
      closingBalance: existing?.closingBalance ?? 0,
      budgetLimit: budget,
      isClosed: existing?.isClosed ?? false,
    );
    await summaryBox.put(monthId, newSummary);

    // 3. Invalidate providers so wallet screen refreshes
    ref.invalidate(currentMonthSummaryProvider);
    ref.invalidate(openingBalanceProvider);
    ref.invalidate(runningBalanceProvider);

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppColors.accentPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Settings', style: AppTypography.headline),
                    Text(
                      'Budget, opening balance & goals',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Opening Balance ─────────────────────────────────────────────
            _Field(
              title: 'Opening Balance',
              controller: _openingCtrl,
              hint: '0.00',
              helper: 'Your cash/bank balance at the start of this month.',
            ),
            const SizedBox(height: 18),

            // ── Monthly Budget Limit ──────────────────────────────────────────
            _Field(
              title: 'Monthly Budget Limit',
              controller: _budgetCtrl,
              hint: '0.00',
              helper: 'Warns you as you approach this spending threshold.',
            ),
            const SizedBox(height: 18),

            // ── Savings Goal ─────────────────────────────────────────────────
            _Field(
              title: 'Savings Target',
              controller: _goalCtrl,
              hint: '0.00',
              helper: 'Semester fund or long-term savings milestone.',
            ),
            const SizedBox(height: 28),

            // ── Save button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save Settings',
                  style: AppTypography.buttonLabel.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable currency input field ─────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String hint;
  final String helper;

  const _Field({
    required this.title,
    required this.controller,
    required this.hint,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.sectionLabel,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.appBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.subtleBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.scoreStat.copyWith(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppColors.accentPrimary,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppTypography.scoreStat.copyWith(
                color: AppColors.textPlaceholder,
                fontSize: 15,
              ),
              prefixText: '৳ ',
              prefixStyle: AppTypography.scoreStat.copyWith(
                color: AppColors.accentPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          helper,
          style: AppTypography.caption,
        ),
      ],
    );
  }
}
