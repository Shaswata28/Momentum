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
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A38),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Wallet Settings',
                style: AppTypography.displayHeading.copyWith(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              'Configure your balance, budget, and savings target.',
              style: AppTypography.bodyText
                  .copyWith(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 28),

            // ── Opening Balance ─────────────────────────────────────────────
            Text('Opening Balance',
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
            const SizedBox(height: 6),
            _Field(
              controller: _openingCtrl,
              hint: '0.00',
              helper:
                  'Your starting balance at the beginning of this month (e.g. cash carried forward).',
            ),
            const SizedBox(height: 20),

            // ── Monthly Budget Limit ──────────────────────────────────────────
            Text('Monthly Budget Limit',
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
            const SizedBox(height: 6),
            _Field(
              controller: _budgetCtrl,
              hint: '0.00',
              helper:
                  'The budget bar will warn you as you approach this spend limit.',
            ),
            const SizedBox(height: 20),

            // ── Savings Goal ─────────────────────────────────────────────────
            Text('Savings Goal',
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
            const SizedBox(height: 6),
            _Field(
              controller: _goalCtrl,
              hint: '0.00',
              helper:
                  'A savings target to track progress toward (e.g. semester fund, emergency fund).',
            ),
            const SizedBox(height: 32),

            // ── Save button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save Settings',
                  style:
                      AppTypography.buttonLabel.copyWith(color: Colors.white),
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
  final TextEditingController controller;
  final String hint;
  final String helper;

  const _Field({
    required this.controller,
    required this.hint,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161619),        // slightly lighter bg
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF252535)), // brighter border
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.bodyText
                .copyWith(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary, // was textMuted
                fontSize: 16,
              ),
              prefixText: '৳ ',
              prefixStyle: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: AppTypography.bodyText.copyWith( // was sectionLabel (JetBrains Mono)
            color: AppColors.textSecondary,        // was textMuted
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
