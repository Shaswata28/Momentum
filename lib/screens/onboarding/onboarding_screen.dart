import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../models/month_summary.dart';
import '../../models/transaction.dart';
import '../../models/wallet_settings.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/notification_service.dart';
import '../main_layout.dart';
import '../../constants/avatar_icons.dart';
import '../../widgets/routine_builder_widget.dart';
import 'package:uuid/uuid.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 1
  final _nameCtrl = TextEditingController();
  int _selectedAvatar = 0;

  // Step 3
  final _openingBalanceCtrl = TextEditingController();
  final _rolloverCtrl = TextEditingController();
  bool _hasBorrowed = false;
  bool _hasLent = false;
  final _borrowedAmtCtrl = TextEditingController();
  final _borrowedNoteCtrl = TextEditingController();
  final _lentAmtCtrl = TextEditingController();
  final _lentNoteCtrl = TextEditingController();

  void _nextPage() {
    if (_currentPage == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your first name.'),
          backgroundColor: AppColors.errorAlert,
        ),
      );
      return;
    }
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    // 1. Save user settings
    final settingsBox = Hive.box<UserSettings>('userSettings');
    await settingsBox.put('user', UserSettings(
      firstName: _nameCtrl.text.trim(),
      avatarIndex: _selectedAvatar,
      isFirstLaunch: false,
    ));

    // 2. Seed / OVERWRITE MonthSummary for current month
    final openingBalance = double.tryParse(_openingBalanceCtrl.text) ?? 0.0;
    final rollover = double.tryParse(_rolloverCtrl.text) ?? 0.0;
    final totalOpening = openingBalance + rollover;

    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final walletRepo = WalletRepository();
    // Always overwrite — delete existing if present
    await walletRepo.saveMonthSummary(MonthSummary(
      id: monthId,
      openingBalance: totalOpening,
      totalIncome: 0,
      totalExpense: 0,
      closingBalance: totalOpening,
    ));

    // 3. Save wallet settings (overwrite)
    final walletSettingsBox = Hive.box<WalletSettings>('walletSettings');
    if (walletSettingsBox.isEmpty) {
      await walletSettingsBox.add(WalletSettings());
    }

    // 4. Log borrowed/lent initial transactions (clear old opening ones first if any)
    const uuid = Uuid();

    final borrowed = double.tryParse(_borrowedAmtCtrl.text) ?? 0.0;
    if (_hasBorrowed && borrowed > 0) {
      await walletRepo.saveTransaction(Transaction(
        id: uuid.v4(),
        date: now,
        direction: Direction.expense,
        amount: borrowed,
        expenseType: ExpenseType.borrowed,
        note: _borrowedNoteCtrl.text.trim().isEmpty
            ? 'Opening: borrowed balance'
            : _borrowedNoteCtrl.text.trim(),
        isSettled: false,
        monthId: monthId,
      ));
    }

    final lent = double.tryParse(_lentAmtCtrl.text) ?? 0.0;
    if (_hasLent && lent > 0) {
      await walletRepo.saveTransaction(Transaction(
        id: uuid.v4(),
        date: now,
        direction: Direction.expense,
        amount: lent,
        expenseType: ExpenseType.lent,
        note: _lentNoteCtrl.text.trim().isEmpty
            ? 'Opening: lent balance'
            : _lentNoteCtrl.text.trim(),
        isSettled: false,
        monthId: monthId,
      ));
    }

    // 5. Request notification permission
    await NotificationService().requestPermissions();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Step progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= _currentPage
                          ? AppColors.accentPrimary
                          : const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: Color(0xFF1E1E2E)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Back', style: AppTypography.buttonLabel.copyWith(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 2 ? 'Get Started' : 'Continue',
                        style: AppTypography.buttonLabel.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Identity ────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hey there 👋', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
          const SizedBox(height: 8),
          Text("Let's set up\nyour profile.", style: AppTypography.displayHeading),
          const SizedBox(height: 32),
          Text('FIRST NAME', style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
          _InputBox(
            controller: _nameCtrl,
            hint: 'What should we call you?',
          ),
          const SizedBox(height: 32),
          Text('PICK AN AVATAR', style: AppTypography.sectionLabel),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: List.generate(kAvatarIcons.length, (i) {
              final selected = _selectedAvatar == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedAvatar = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentPrimary.withValues(alpha: 0.15)
                        : const Color(0xFF121217),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.accentPrimary : const Color(0xFF1A1A24),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    kAvatarIcons[i],
                    color: selected ? AppColors.accentPrimary : AppColors.textMuted,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Weekly Routine Builder ─────────────────────────────────────────
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('Step 2 of 3', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('Build your weekly routine.', style: AppTypography.displayHeading),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentTagBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.accentPrimary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Don't worry about making it perfect. You can always update this later from Profile › Edit Routine.",
                      style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Actual embedded routine grid — fills remaining space
          Expanded(
            child: ColoredBox(
              color: AppColors.appBackground,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const RoutineBuilderWidget(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Financial Baseline ──────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 3 of 3', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
          const SizedBox(height: 8),
          Text('Financial\nbaseline.', style: AppTypography.displayHeading),
          const SizedBox(height: 6),
          Text('Set where you stand today.', style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 28),

          Text('CURRENT CASH BALANCE', style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
          _NumericInputBox(controller: _openingBalanceCtrl, hint: '0.00'),
          const SizedBox(height: 16),

          Text('ROLLOVER FROM PREVIOUS MONTH', style: AppTypography.sectionLabel),
          const SizedBox(height: 4),
          Text('Any cash you held before using this app.', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 8),
          _NumericInputBox(controller: _rolloverCtrl, hint: '0.00 (optional)'),
          const SizedBox(height: 28),

          // Borrowed toggle
          _ToggleRow(
            label: 'Do you owe money to anyone?',
            value: _hasBorrowed,
            onChanged: (v) => setState(() => _hasBorrowed = v),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _hasBorrowed
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AMOUNT BORROWED', style: AppTypography.sectionLabel),
                        const SizedBox(height: 8),
                        _NumericInputBox(controller: _borrowedAmtCtrl, hint: '0.00'),
                        const SizedBox(height: 8),
                        _InputBox(controller: _borrowedNoteCtrl, hint: 'Who do you owe? (optional)'),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),

          // Lent toggle
          _ToggleRow(
            label: 'Does anyone owe you money?',
            value: _hasLent,
            onChanged: (v) => setState(() => _hasLent = v),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _hasLent
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AMOUNT LENT', style: AppTypography.sectionLabel),
                        const SizedBox(height: 8),
                        _NumericInputBox(controller: _lentAmtCtrl, hint: '0.00'),
                        const SizedBox(height: 8),
                        _InputBox(controller: _lentNoteCtrl, hint: 'Who owes you? (optional)'),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1520),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.accentPrimary, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: You can log fixed expenses like tuition or rent in the Wallet tab to keep your monthly budget accurate.',
                    style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared input components ─────────────────────────────────────────────────

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _InputBox({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _NumericInputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _NumericInputBox({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppTypography.scoreStat.copyWith(color: AppColors.textPrimary, fontSize: 20),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTypography.scoreStat.copyWith(color: AppColors.textMuted, fontSize: 20),
          prefixText: '৳ ',
          prefixStyle: AppTypography.scoreStat.copyWith(color: AppColors.textSecondary, fontSize: 20),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A1A24)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentPrimary,
            trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                ? AppColors.accentPrimary.withValues(alpha: 0.3)
                : const Color(0xFF1E1E2E),
            ),
          ),
        ],
      ),
    );
  }
}
