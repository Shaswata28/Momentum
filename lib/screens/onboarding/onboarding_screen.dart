import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../models/user_settings.dart';
import '../../models/month_summary.dart';
import '../../models/wallet_settings.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/notification_service.dart';
import '../../services/dnd_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../constants/avatar_icons.dart';
import '../main_layout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalSteps = 5; // 0,1,2 carousel; 3 profile; 4 ready

  // Profile data
  final TextEditingController _nameController = TextEditingController();
  int _selectedAvatar = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextPage() {
    if (_currentPage == 3 && _nameController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your name to continue.', style: AppTypography.bodyText),
          backgroundColor: AppColors.errorAlert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_currentPage < _totalSteps - 1) {
      _goToPage(_currentPage + 1);
    } else {
      _completeOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    // 1. Request notifications and DND permissions
    try {
      await NotificationService().requestPermissions();
      await DndService().requestDndPermissionIfNeeded();
      await NotificationService().scheduleEODPrompt();
    } catch (_) {}

    // 2. Save User Settings
    final settingsBox = Hive.box<UserSettings>('userSettings');
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Friend';
    await settingsBox.put(
      'user',
      UserSettings(
        firstName: name,
        avatarIndex: _selectedAvatar,
        isFirstLaunch: false,
        hasSeenCoachMarks: false,
      ),
    );

    // 3. Initialize default wallet summary for current month if empty
    final walletRepo = WalletRepository();
    final now = DateTime.now();
    final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final existingSummary = walletRepo.getMonthSummary(monthId);
    if (existingSummary == null) {
      await walletRepo.saveMonthSummary(
        MonthSummary(
          id: monthId,
          openingBalance: 0.0,
          totalIncome: 0.0,
          totalExpense: 0.0,
          closingBalance: 0.0,
        ),
      );
    }

    final walletSettingsBox = Hive.box<WalletSettings>('walletSettings');
    if (walletSettingsBox.isEmpty) {
      await walletSettingsBox.add(WalletSettings());
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim, secAnim) => const MainLayout(),
        transitionsBuilder: (context, animation, secAnim, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation / header row
            _buildTopBar(),

            // Main Carousel & Setup pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _currentPage < 3
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildIntroPage1(),
                  _buildIntroPage2(),
                  _buildIntroPage3(),
                  _buildProfileSetupPage(),
                  _buildReadyPage(),
                ],
              ),
            ),

            // Bottom CTA row
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isSetup = _currentPage >= 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            if (_currentPage > 0)
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textSecondary),
                onPressed: _prevPage,
                splashRadius: 20,
              )
            else
              const SizedBox(width: 40),
            const Spacer(),
            if (!isSetup)
              TextButton(
                onPressed: () => _goToPage(3),
                child: Text(
                  'Skip',
                  style: AppTypography.buttonLabel.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Text(
                  'Step ${_currentPage - 2} of 2',
                  style: AppTypography.tagChip.copyWith(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Carousel Page 1: Welcome & Mission ─────────────────────────────────────
  Widget _buildIntroPage1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPrimary.withValues(alpha: 0.35),
                  blurRadius: 36,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.5),
              child: Image.asset(
                'assets/icon/Momentum_appIcon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.cardBackground,
                  child: Center(
                    child: Icon(Icons.flash_on_rounded, size: 52, color: AppColors.accentPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'MOMENTUM',
            style: AppTypography.tagChip.copyWith(
              color: AppColors.accentPrimary,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your day,\nyour momentum.',
            textAlign: TextAlign.center,
            style: AppTypography.displayHeading.copyWith(
              fontSize: 32,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A calm daily companion designed for daily routines, quiet finances, and intentional self-improvement.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ── Carousel Page 2: Three Pillars ─────────────────────────────────────────
  Widget _buildIntroPage2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeaturePill(Icons.check_circle_outline_rounded, 'Routines', AppColors.successDone),
              const SizedBox(width: 8),
              _buildFeaturePill(Icons.account_balance_wallet_outlined, 'Finances', AppColors.accentPrimary),
              const SizedBox(width: 8),
              _buildFeaturePill(Icons.insights_rounded, 'Insights', AppColors.warningTag),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Build routines.\nTrack spending.\nGain insights.',
            textAlign: TextAlign.center,
            style: AppTypography.displayHeading.copyWith(
              fontSize: 30,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Everything you need to stay on track and cultivate focus, without noise, clutter, or distractions.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.tagChip.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Carousel Page 3: The Philosophy ────────────────────────────────────────
  Widget _buildIntroPage3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.subtleBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.format_quote_rounded, size: 36, color: AppColors.accentPrimary),
                const SizedBox(height: 12),
                Text(
                  '"Small daily improvements compound into remarkable long-term results."',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyText.copyWith(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '— James Clear, Atomic Habits',
                  style: AppTypography.tagChip.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Ready to start?',
            textAlign: TextAlign.center,
            style: AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your profile in 30 seconds.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Setup Step 1: Profile & Avatar ─────────────────────────────────────────
  Widget _buildProfileSetupPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's get to know you.",
            style: AppTypography.displayHeading.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your avatar and tell us what to call you.',
            style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 30),

          // Name Input
          Text(
            'YOUR NAME',
            style: AppTypography.sectionLabel.copyWith(
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.subtleBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: AppColors.accentPrimary,
              decoration: InputDecoration(
                hintText: 'e.g. Arnob',
                hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textPlaceholder),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Avatar Selector
          Text(
            'PICK AN AVATAR',
            style: AppTypography.sectionLabel.copyWith(
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kAvatarIcons.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final isSelected = _selectedAvatar == index;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAvatar = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentPrimary.withValues(alpha: 0.18)
                        : AppColors.cardBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      kAvatarIcons[index],
                      size: 26,
                      color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Setup Step 2: You're all set! ──────────────────────────────────────────
  Widget _buildReadyPage() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'there';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successDone.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.successDone.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Center(
              child: Icon(Icons.check_rounded, size: 44, color: AppColors.successDone),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            "You're all set, $name! 🎉",
            textAlign: TextAlign.center,
            style: AppTypography.displayHeading.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Your daily dashboard is ready. You can configure your routines and set up your wallet whenever you want.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: AppColors.accentPrimary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Notifications & DND will be requested to provide seamless routine tracking.',
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Controls ────────────────────────────────────────────────────────
  Widget _buildBottomControls() {
    final isLastPage = _currentPage == _totalSteps - 1;
    final isCarousel = _currentPage < 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCarousel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accentPrimary : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLastPage
                              ? 'Launch Momentum →'
                              : (_currentPage == 3
                                  ? 'Continue →'
                                  : (_currentPage == 0 ? 'Get Started →' : 'Next →')),
                          style: AppTypography.buttonLabel.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
