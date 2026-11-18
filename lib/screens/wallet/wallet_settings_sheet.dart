import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../models/wallet_settings.dart';
import '../../models/month_summary.dart';
import '../../providers/wallet_providers.dart';

class WalletSettingsSheet extends ConsumerStatefulWidget {
  const WalletSettingsSheet({super.key});

  @override
  ConsumerState<WalletSettingsSheet> createState() =>
      _WalletSettingsSheetState();
}

class _WalletSettingsSheetState extends ConsumerState<WalletSettingsSheet> {
  bool _saving = false;
  String? _error;
  late final String _monthId;
  late final TextEditingController _openingCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _goalCtrl;

  @override
  void initState() {
    super.initState();
    final settingsBox = Hive.box<WalletSettings>('walletSettings');
    final settings = settingsBox.isEmpty
        ? WalletSettings()
        : settingsBox.getAt(0)!;

    _monthId = ref.read(selectedMonthIdProvider);
    final monthId = _monthId;
    final summaryBox = Hive.box<MonthSummary>('monthSummaries');
    final summary = summaryBox.get(monthId);

    _openingCtrl = TextEditingController(
      text: summary?.openingBalance != null
          ? summary!.openingBalance.toStringAsFixed(2)
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

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();

    final opening = double.tryParse(_openingCtrl.text) ?? 0.0;
    final budget = double.tryParse(_budgetCtrl.text) ?? 0.0;
    final goal = double.tryParse(_goalCtrl.text) ?? 0.0;
    final values = [_openingCtrl.text, _budgetCtrl.text, _goalCtrl.text];
    if (values.any(
          (value) =>
              value.trim().isNotEmpty &&
              double.tryParse(value)?.isFinite != true,
        ) ||
        budget < 0 ||
        goal < 0) {
      setState(
        () => _error =
            'Enter finite amounts. Budget and goal cannot be negative.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
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
      final monthId = _monthId;
      final summaryBox = Hive.box<MonthSummary>('monthSummaries');
      final existing = summaryBox.get(monthId);
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
      ref.read(walletNotifierProvider.notifier).refresh();

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Could not save settings. Your inputs are kept; please retry.',
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
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
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(
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
                    Icons.tune_rounded,
                    color: AppColors.accentPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Settings', style: AppTypography.headline),
                      Text(
                        'Opening: $_monthId. Budget & goal: all months.',
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Opening Balance ─────────────────────────────────────────────
            _Field(
              title: 'Opening Balance',
              controller: _openingCtrl,
              hint: '0.00',
              helper:
                  'Cash/bank balance at the start of $_monthId. Not savings.',
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
            if (_error != null)
              Text(
                _error!,
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.errorAlert,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: (isRetro && !AppColors.isDark)
                      ? AppColors.textPrimary
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    side: isRetro
                        ? BorderSide(color: AppColors.cardBorder, width: 2.0)
                        : BorderSide.none,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _saving ? 'Saving...' : 'Save Settings',
                  style: AppTypography.buttonLabel.copyWith(
                    fontSize: isRetro ? 11 : 14,
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
    final isRetro = AppColors.isRetro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTypography.sectionLabel),
        const SizedBox(height: 8),
        Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTypography.scoreStat.copyWith(
              color: AppColors.textPrimary,
              fontSize: isRetro ? 17 : 15,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppColors.accentPrimary,
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: hint,
              hintStyle: AppTypography.scoreStat.copyWith(
                color: AppColors.textPlaceholder,
                fontSize: isRetro ? 17 : 15,
              ),
              prefixText: '৳ ',
              prefixStyle: AppTypography.scoreStat.copyWith(
                color: AppColors.accentPrimary,
                fontSize: isRetro ? 17 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(helper, style: AppTypography.caption),
      ],
    );
  }
}
