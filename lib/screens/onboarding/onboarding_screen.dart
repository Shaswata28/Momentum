import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dnd/flutter_dnd.dart';
import '../../models/user_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../models/month_summary.dart';
import '../../models/transaction.dart';
import '../../models/wallet_settings.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/notification_service.dart';
import '../../services/dnd_service.dart';
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
  bool _isFinishing = false;
  bool _isDone = false;
  static const int _totalPages = 5;

  // Profile
  final _nameCtrl = TextEditingController();
  int _selectedAvatar = 0;

  // Wallet
  final _openingBalanceCtrl = TextEditingController();
  final _rolloverCtrl = TextEditingController();
  bool _hasBorrowed = false;
  bool _hasLent = false;
  final _borrowedAmtCtrl = TextEditingController();
  final _borrowedNoteCtrl = TextEditingController();
  final _lentAmtCtrl = TextEditingController();
  final _lentNoteCtrl = TextEditingController();

  // Permissions
  bool _notifGranted = false;
  bool _dndGranted = false;

  Future<void> _requestNotifPermission() async {
    await NotificationService().requestPermissions();
    setState(() => _notifGranted = true);
  }

  Future<void> _requestDndPermission() async {
    await DndService().requestDndPermissionIfNeeded();
    await Future.delayed(const Duration(milliseconds: 500));
    final granted = await FlutterDnd.isNotificationPolicyAccessGranted ?? false;
    setState(() => _dndGranted = granted);
  }

  void _nextPage() {
    if (_currentPage == 1 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter your first name.'),
        backgroundColor: AppColors.errorAlert,
      ));
      return;
    }
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _prevPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _skipRoutine() {
    _pageController.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _finish() async {
    setState(() => _isFinishing = true);

    final settingsBox = Hive.box<UserSettings>('userSettings');
    await settingsBox.put('user', UserSettings(
      firstName: _nameCtrl.text.trim(),
      avatarIndex: _selectedAvatar,
      isFirstLaunch: false,
    ));

    final openingBalance = double.tryParse(_openingBalanceCtrl.text) ?? 0.0;
    final rollover = double.tryParse(_rolloverCtrl.text) ?? 0.0;
    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final walletRepo = WalletRepository();
    await walletRepo.saveMonthSummary(MonthSummary(
      id: monthId,
      openingBalance: openingBalance + rollover,
      totalIncome: 0,
      totalExpense: 0,
      closingBalance: openingBalance + rollover,
    ));

    final walletSettingsBox = Hive.box<WalletSettings>('walletSettings');
    if (walletSettingsBox.isEmpty) await walletSettingsBox.add(WalletSettings());

    const uuid = Uuid();
    final borrowed = double.tryParse(_borrowedAmtCtrl.text) ?? 0.0;
    if (_hasBorrowed && borrowed > 0) {
      await walletRepo.saveTransaction(Transaction(
        id: uuid.v4(), date: now, direction: Direction.expense,
        amount: borrowed, expenseType: ExpenseType.borrowed,
        note: _borrowedNoteCtrl.text.trim().isEmpty ? 'Opening: borrowed balance' : _borrowedNoteCtrl.text.trim(),
        isSettled: false, monthId: monthId,
      ));
    }
    final lent = double.tryParse(_lentAmtCtrl.text) ?? 0.0;
    if (_hasLent && lent > 0) {
      await walletRepo.saveTransaction(Transaction(
        id: uuid.v4(), date: now, direction: Direction.expense,
        amount: lent, expenseType: ExpenseType.lent,
        note: _lentNoteCtrl.text.trim().isEmpty ? 'Opening: lent balance' : _lentNoteCtrl.text.trim(),
        isSettled: false, monthId: monthId,
      ));
    }

    await NotificationService().scheduleEODPrompt();
    setState(() { _isFinishing = false; _isDone = true; });
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDone) {
      return Scaffold(
        backgroundColor: AppColors.appBackground,
        body: _SuccessAnimation(name: _nameCtrl.text.trim()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: List.generate(_totalPages - 1, (i) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i < _currentPage ? AppColors.accentPrimary : const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
              )
            else
              const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [_buildWelcome(), _buildStep1(), _buildStep2(), _buildStep3(), _buildPermissions()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _currentPage == 0
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text("Let's get started", style: AppTypography.buttonLabel.copyWith(color: Colors.white, fontSize: 15)),
                      ),
                    )
                  : Row(
                      children: [
                        if (_currentPage > 1) ...[
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
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isFinishing ? null : _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isFinishing
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _currentPage == _totalPages - 1 ? 'Get Started' : 'Continue',
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

  // ─── Page 0: Welcome ────────────────────────────────────────────────────────
  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/icon/Momentum_appIcon_Foreground.png', width: 96, height: 96),
          const SizedBox(height: 24),
          Text('Momentum', style: AppTypography.displayHeading.copyWith(fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'Your daily routine, habits,\nand finances — all in one place.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 48),
          _FeatureRow(icon: Icons.today_outlined, label: 'Plan your day with time-blocked tasks'),
          const SizedBox(height: 16),
          _FeatureRow(icon: Icons.account_balance_wallet_outlined, label: 'Track income, expenses & savings'),
          const SizedBox(height: 16),
          _FeatureRow(icon: Icons.insights_outlined, label: 'Reflect with weekly health scores'),
        ],
      ),
    );
  }

  // ─── Page 1: Profile ────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1 of 4  ·  Your Profile', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
          const SizedBox(height: 10),
          Text("What should we\ncall you?", style: AppTypography.displayHeading),
          const SizedBox(height: 6),
          Text('This shows up in your daily greeting.', style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          Text('FIRST NAME', style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
          _InputBox(controller: _nameCtrl, hint: 'e.g. Alex'),
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
                    color: selected ? AppColors.accentPrimary.withValues(alpha: 0.15) : const Color(0xFF121217),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? AppColors.accentPrimary : const Color(0xFF1A1A24), width: selected ? 2 : 1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(kAvatarIcons[i], color: selected ? AppColors.accentPrimary : AppColors.textMuted, size: 28),
                      if (selected)
                        Positioned(
                          top: 4, right: 4,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(color: AppColors.accentPrimary, shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Page 2: Routine ────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Expanded(child: Text('2 of 4  ·  Weekly Routine', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary))),
                TextButton(
                  onPressed: _skipRoutine,
                  child: Text('Skip for now', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('Build your weekly routine.', style: AppTypography.displayHeading),
          ),
          const SizedBox(height: 10),
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
                  Expanded(child: Text("You can always update this later from Profile › Edit Routine.", style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ColoredBox(
              color: AppColors.appBackground,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: const RoutineBuilderWidget()),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page 3: Wallet ──────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3 of 4  ·  Financial Baseline', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
          const SizedBox(height: 10),
          Text('Set where you\nstand today.', style: AppTypography.displayHeading),
          const SizedBox(height: 6),
          Text('You can skip this and set it up later in Wallet.', style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          Text('CURRENT CASH BALANCE', style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
          _NumericInputBox(controller: _openingBalanceCtrl, hint: '0.00'),
          const SizedBox(height: 16),
          Text('ROLLOVER FROM PREVIOUS MONTH', style: AppTypography.sectionLabel),
          const SizedBox(height: 4),
          Text('Any cash you held before using this app.', style: AppTypography.bodyText.copyWith(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          _NumericInputBox(controller: _rolloverCtrl, hint: '0.00 (optional)'),
          const SizedBox(height: 24),
          _ToggleRow(label: 'Do you owe money to anyone?', value: _hasBorrowed, onChanged: (v) => setState(() => _hasBorrowed = v)),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _hasBorrowed
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AMOUNT BORROWED', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      _NumericInputBox(controller: _borrowedAmtCtrl, hint: '0.00'),
                      const SizedBox(height: 8),
                      _InputBox(controller: _borrowedNoteCtrl, hint: 'Who do you owe? (optional)'),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _ToggleRow(label: 'Does anyone owe you money?', value: _hasLent, onChanged: (v) => setState(() => _hasLent = v)),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _hasLent
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AMOUNT LENT', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      _NumericInputBox(controller: _lentAmtCtrl, hint: '0.00'),
                      const SizedBox(height: 8),
                      _InputBox(controller: _lentNoteCtrl, hint: 'Who owes you? (optional)'),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
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
                Expanded(child: Text('Tip: Log fixed expenses like tuition or rent in the Wallet tab to keep your monthly budget accurate.', style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Page 4: Permissions ────────────────────────────────────────────────────
  Widget _buildPermissions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('4 of 4  ·  Permissions', style: AppTypography.sectionLabel.copyWith(color: AppColors.accentPrimary)),
          const SizedBox(height: 10),
          Text('Stay on track\nwith reminders.', style: AppTypography.displayHeading),
          const SizedBox(height: 6),
          Text('Grant these so Momentum can work fully. You can change them anytime in Settings.', style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          _PermissionCard(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            description: 'Task reminders before they start, and a nudge at the end of the day for your check-in.',
            granted: _notifGranted,
            onGrant: _requestNotifPermission,
          ),
          const SizedBox(height: 16),
          _PermissionCard(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Do Not Disturb',
            description: 'Silences your phone during tasks that have DND enabled — only when you choose it per task.',
            granted: _dndGranted,
            onGrant: _requestDndPermission,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1520),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.accentPrimary, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text('All data stays on your device. No account, no cloud sync.', style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // end _OnboardingScreenState

// ─── Success animation ────────────────────────────────────────────────────────
class _SuccessAnimation extends StatefulWidget {
  final String name;
  const _SuccessAnimation({required this.name});
  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: AppColors.successDone.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.successDone, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                widget.name.isNotEmpty ? 'Welcome, ${widget.name}!' : "You're all set!",
                style: AppTypography.displayHeading,
              ),
              const SizedBox(height: 8),
              Text('Taking you to your dashboard…', style: AppTypography.bodyText),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.accentPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.accentPrimary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary))),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onGrant;
  const _PermissionCard({required this.icon, required this.title, required this.description, required this.granted, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: granted ? AppColors.successDone.withValues(alpha: 0.08) : const Color(0xFF121217),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: granted ? AppColors.successDone.withValues(alpha: 0.4) : const Color(0xFF1A1A24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: granted ? AppColors.successDone.withValues(alpha: 0.15) : AppColors.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(granted ? Icons.check_rounded : icon, color: granted ? AppColors.successDone : AppColors.accentPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle),
                const SizedBox(height: 4),
                Text(description, style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary, fontSize: 13)),
                if (!granted) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onGrant,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Text('Allow', style: AppTypography.buttonLabel.copyWith(color: AppColors.accentPrimary, fontSize: 13)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text('Granted', style: AppTypography.sectionLabel.copyWith(color: AppColors.successDone)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _InputBox({required this.controller, required this.hint});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF121217), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1A1A24))),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted)),
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
      decoration: BoxDecoration(color: const Color(0xFF121217), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1A1A24))),
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
      decoration: BoxDecoration(color: const Color(0xFF121217), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1A1A24))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accentPrimary,
            trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.accentPrimary.withValues(alpha: 0.3) : const Color(0xFF1E1E2E)),
          ),
        ],
      ),
    );
  }
}
