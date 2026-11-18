import 'package:flutter/material.dart';
import '../../widgets/restricted_settings_help.dart';
import '../../widgets/app_back_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dnd/flutter_dnd.dart';
import 'package:hive/hive.dart';
import '../../models/user_settings.dart';
import '../../models/month_summary.dart';
import '../../models/wallet_settings.dart';
import '../../repositories/wallet_repository.dart';
import '../../services/notification_service.dart';
import '../../services/dnd_service.dart';
import '../../services/focus_blocker_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/retro_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../constants/avatar_icons.dart';
import '../../providers/theme_provider.dart';
import '../main_layout.dart';

// Permission grant status
enum _PermStatus { idle, requesting, granted, denied }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Pages: 0=Welcome, 1=Features, 2=Theme, 3=Profile, 4=Permissions, 5=Ready
  static const int _totalSteps = 6;
  static const int _carouselCount = 3; // pages 0,1,2 show dot indicators

  // Profile data
  final TextEditingController _nameController = TextEditingController();
  int _selectedAvatar = 0;
  bool _isSaving = false;

  // Permission states
  _PermStatus _notifStatus = _PermStatus.idle;
  _PermStatus _shieldStatus = _PermStatus.idle;
  _PermStatus _dndStatus = _PermStatus.idle;

  // Per-page entrance animation controllers
  late final List<AnimationController> _pageControllers;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  // Welcome page logo pulse
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pageControllers = List.generate(
      _totalSteps,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      ),
    );

    _fadeAnims = _pageControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    _slideAnims = _pageControllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    // Welcome logo gentle pulse
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Animate first page in
    _pageControllers[0].forward();

    // Initial check of already-granted permissions
    _checkAllPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _logoController.stop();
      _logoController.value = 0.5;
      for (final controller in _pageControllers) {
        controller.value = 1;
      }
    } else if (!_logoController.isAnimating) {
      _logoController.repeat(reverse: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _nameController.dispose();
    for (final c in _pageControllers) {
      c.dispose();
    }
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _checkAllPermissions() async {
    try {
      final isDnd = await FlutterDnd.isNotificationPolicyAccessGranted;
      if (isDnd == true && mounted) {
        setState(() => _dndStatus = _PermStatus.granted);
      }
    } catch (_) {}

    try {
      final isShield = await FocusBlockerService().isAccessibilityGranted();
      if (isShield && mounted) {
        setState(() => _shieldStatus = _PermStatus.granted);
      }
    } catch (_) {}
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    if (_reduceMotion) {
      _pageControllers[page].value = 1;
    } else {
      _pageControllers[page].forward(from: 0);
    }
  }

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    if (_reduceMotion) {
      _pageController.jumpToPage(page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextPage() {
    if (_currentPage == 3 && _nameController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter your name to continue.',
            style: AppTypography.bodyText,
          ),
          backgroundColor: AppColors.errorAlert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppColors.isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(10),
          ),
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
    if (_currentPage > 0) _goToPage(_currentPage - 1);
  }

  // ── Permission requests ────────────────────────────────────────────────────

  Future<void> _requestNotifications() async {
    if (_notifStatus == _PermStatus.requesting) return;
    setState(() => _notifStatus = _PermStatus.requesting);
    try {
      await NotificationService().requestPermissions();
      final scheduled = await NotificationService().scheduleEODPrompt();
      if (mounted)
        setState(
          () => _notifStatus = scheduled
              ? _PermStatus.granted
              : _PermStatus.denied,
        );
    } catch (_) {
      if (mounted) setState(() => _notifStatus = _PermStatus.denied);
    }
  }

  Future<void> _requestShield() async {
    if (_shieldStatus == _PermStatus.requesting) return;
    setState(() => _shieldStatus = _PermStatus.requesting);
    try {
      final isGranted = await FocusBlockerService().isAccessibilityGranted();
      if (isGranted) {
        if (mounted) setState(() => _shieldStatus = _PermStatus.granted);
        return;
      }
      await FocusBlockerService().openAccessibilitySettings();
      // Status will auto-update on return in didChangeAppLifecycleState
    } catch (_) {
      if (mounted) setState(() => _shieldStatus = _PermStatus.denied);
    }
  }

  Future<void> _requestDnd() async {
    if (_dndStatus == _PermStatus.requesting) return;
    setState(() => _dndStatus = _PermStatus.requesting);
    try {
      final isGranted = await FlutterDnd.isNotificationPolicyAccessGranted;
      if (isGranted == true) {
        if (mounted) setState(() => _dndStatus = _PermStatus.granted);
        return;
      }
      await DndService().requestDndPermissionIfNeeded();
      // Status will auto-update on return in didChangeAppLifecycleState
    } catch (_) {
      if (mounted) setState(() => _dndStatus = _PermStatus.denied);
    }
  }

  // ── Complete Onboarding ────────────────────────────────────────────────────

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    // Permissions are optional; finishing setup must not prompt again after denial.
    try {
      await NotificationService().scheduleEODPrompt();
    } catch (_) {}

    try {
      // Save User Settings
      final settingsBox = Hive.box<UserSettings>('userSettings');
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Friend';
      // Initialize default wallet data
      final walletRepo = WalletRepository();
      final now = DateTime.now();
      final monthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      if (walletRepo.getMonthSummary(monthId) == null) {
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

      await settingsBox.put(
        'user',
        UserSettings(
          firstName: name,
          avatarIndex: _selectedAvatar,
          isFirstLaunch: false,
          hasSeenCoachMarks: false,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 400),
          pageBuilder: (context, anim, secAnim) => const MainLayout(),
          transitionsBuilder: (context, animation, secAnim, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not finish setup. Your inputs are still here. Please try again.',
          ),
        ),
      );
    }
  }

  // ── Animated page wrapper ──────────────────────────────────────────────────
  Widget _animated(int pageIndex, Widget child) {
    if (pageIndex == 0 || pageIndex == 1 || pageIndex == 5) {
      final content = child;
      child = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        ),
      );
    }
    if (_reduceMotion) return child;
    return FadeTransition(
      opacity: _fadeAnims[pageIndex],
      child: SlideTransition(position: _slideAnims[pageIndex], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final isRetro = AppColors.isRetro;
    final isCarousel = _currentPage < _carouselCount;
    final isSetup = _currentPage >= 3;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isRetro, isSetup, isCarousel),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _currentPage < _carouselCount
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  _buildWelcomePage(isRetro),
                  _buildFeaturesPage(isRetro),
                  _buildThemePage(isRetro),
                  _buildProfilePage(isRetro),
                  _buildPermissionsPage(isRetro),
                  _buildReadyPage(isRetro),
                ],
              ),
            ),
            _buildBottomControls(isRetro, isCarousel),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isRetro, bool isSetup, bool isCarousel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _currentPage > 0 ? 1.0 : 0.0,
              child: AppBackButton(
                onPressed: _currentPage > 0 ? _prevPage : null,
              ),
            ),
            const Spacer(),
            if (!isSetup)
              GestureDetector(
                onTap: () => _goToPage(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: isRetro ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    'Skip',
                    style: AppTypography.buttonLabel.copyWith(
                      color: AppColors.textMuted,
                      fontSize: isRetro ? 9 : 12,
                    ),
                  ),
                ),
              )
            else if (_currentPage == 5)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.cardBackground
                      : AppColors.successDone.withValues(alpha: 0.12),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : AppColors.successDone.withValues(alpha: 0.35),
                    width: isRetro ? 2.0 : 1.0,
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
                      Icons.check_circle_rounded,
                      size: 13,
                      color: isRetro && !AppColors.isDark
                          ? AppColors.successDone
                          : AppColors.successDone,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isRetro ? 'READY' : 'Ready',
                      style: isRetro
                          ? RetroTypography.overline.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 8.5,
                            )
                          : AppTypography.tagChip.copyWith(
                              color: isRetro && !AppColors.isDark
                                  ? AppColors.textPrimary
                                  : AppColors.successDone,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isRetro
                        ? AppColors.cardBackground
                        : AppColors.accentPrimary.withValues(alpha: 0.1),
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(10),
                    border: Border.all(
                      color: isRetro
                          ? AppColors.cardBorder
                          : AppColors.accentPrimary.withValues(alpha: 0.3),
                      width: isRetro ? 2.0 : 1.0,
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
                  child: Text(
                    isRetro
                        ? 'STEP ${_currentPage - 2} OF 2'
                        : 'Step ${_currentPage - 2} of 2',
                    style: isRetro
                        ? RetroTypography.overline.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 8.5,
                          )
                        : AppTypography.tagChip.copyWith(
                            color: AppColors.accentPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Page 0: Welcome ────────────────────────────────────────────────────────
  Widget _buildWelcomePage(bool isRetro) {
    return _animated(
      0,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _logoScale,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(22),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : Colors.white.withValues(alpha: 0.1),
                    width: isRetro ? 2.0 : 1.5,
                  ),
                  boxShadow: isRetro
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(5, 5),
                            blurRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: AppColors.accentPrimary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 36,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(20.5),
                  child: Image.asset(
                    'assets/icon/Momentum_appIcon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(
                        Icons.flash_on_rounded,
                        size: 42,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.1),
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(
                    alpha: isRetro ? 0.5 : 0.25,
                  ),
                  width: isRetro ? 1.5 : 1.0,
                ),
              ),
              child: Text(
                'MOMENTUM',
                style: AppTypography.tagChip.copyWith(
                  color: AppColors.accentPrimary,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                  fontSize: isRetro ? 8.5 : 10.5,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Your day,\nyour momentum.',
              textAlign: TextAlign.center,
              style: AppTypography.displayHeading.copyWith(
                fontSize: isRetro ? 18 : 32,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'A calm daily companion built for routines, quiet finances, and intentional living.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: isRetro ? 11 : 14,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 36),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniPill(
                  Icons.check_circle_outline_rounded,
                  'Routines',
                  AppColors.successDone,
                  isRetro,
                ),
                _buildMiniPill(
                  Icons.account_balance_wallet_outlined,
                  'Wallet',
                  AppColors.accentPrimary,
                  isRetro,
                ),
                _buildMiniPill(
                  Icons.insights_rounded,
                  'Insights',
                  AppColors.warningTag,
                  isRetro,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPill(
    IconData icon,
    String label,
    Color color,
    bool isRetro,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isRetro ? 0.5 : 0.22),
          width: isRetro ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.tagChip.copyWith(
              color: AppColors.textPrimary,
              fontSize: isRetro ? 8 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 1: Features ───────────────────────────────────────────────────────
  Widget _buildFeaturesPage(bool isRetro) {
    final features = [
      (
        icon: Icons.check_circle_outline_rounded,
        label: 'Daily Routines',
        desc: 'Build powerful morning & evening habits that actually stick.',
        color: AppColors.successDone,
        delay: 0,
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'Smart Wallet',
        desc: 'Track income, expenses, recurring bills and savings goals.',
        color: AppColors.accentPrimary,
        delay: 100,
      ),
      (
        icon: Icons.insights_rounded,
        label: 'Insights & Streaks',
        desc: 'See trends, momentum score, and energy levels over time.',
        color: AppColors.warningTag,
        delay: 200,
      ),
    ];

    return _animated(
      1,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Everything\nyou need.',
              style: AppTypography.displayHeading.copyWith(
                fontSize: isRetro ? 18 : 30,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Three pillars to build momentum every single day.',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: isRetro ? 11 : 13.5,
              ),
            ),
            const SizedBox(height: 28),
            ...features.asMap().entries.map((e) {
              final f = e.value;
              return TweenAnimationBuilder<double>(
                key: ValueKey('feat_${e.key}_$_currentPage'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: _reduceMotion
                    ? Duration.zero
                    : Duration(milliseconds: 400 + f.delay),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 20),
                    child: child,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFeatureCard(
                    isRetro,
                    f.icon,
                    f.label,
                    f.desc,
                    f.color,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    bool isRetro,
    IconData icon,
    String label,
    String desc,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(14),
        border: Border.all(
          color: isRetro ? AppColors.cardBorder : color.withValues(alpha: 0.2),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(10),
              border: isRetro
                  ? Border.all(color: AppColors.cardBorder, width: 1.5)
                  : null,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: isRetro ? 10 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: isRetro ? 10 : 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 2: Theme Picker ───────────────────────────────────────────────────
  Widget _buildThemePage(bool isRetro) {
    final currentTheme = ref.watch(themeModeProvider);
    final isRetroMode = currentTheme.isRetro;
    final isDark = (currentTheme == AppThemeMode.system)
        ? AppColors.isDark
        : currentTheme.isDark;

    return _animated(
      2,
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey('theme_icon_$_currentPage'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(14),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : AppColors.accentPrimary.withValues(alpha: 0.3),
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
                child: Icon(
                  Icons.palette_outlined,
                  size: 26,
                  color: AppColors.accentPrimary,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Make it yours.',
              style: AppTypography.displayHeading.copyWith(
                fontSize: isRetro ? 18 : 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a visual style and appearance. You can change this anytime in Settings.',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: isRetro ? 11 : 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'THEME',
              style: AppTypography.sectionLabel.copyWith(
                fontSize: isRetro ? 8.5 : 10,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            _buildThemeCards(isRetroMode, isDark),

            const SizedBox(height: 24),

            Text(
              'APPEARANCE',
              style: AppTypography.sectionLabel.copyWith(
                fontSize: isRetro ? 8.5 : 10,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            _buildAppearanceToggle(isRetroMode, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCards(bool isRetroMode, bool isDark) {
    final options = [
      (
        id: 'classic',
        label: 'Classic',
        desc: 'Clean & modern',
        icon: Icons.auto_awesome_rounded,
        isSelected: !isRetroMode,
      ),
      (
        id: 'retro',
        label: 'Retro',
        desc: 'Pixel & bold',
        icon: Icons.videogame_asset_rounded,
        isSelected: isRetroMode,
      ),
    ];

    return Row(
      children: options.map((opt) {
        final sel = opt.isSelected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt.id == 'classic' ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(themeModeProvider.notifier)
                    .setRetro(opt.id == 'retro');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.accentPrimary.withValues(alpha: 0.1)
                      : AppColors.cardBackground,
                  borderRadius: isRetroMode
                      ? BorderRadius.zero
                      : BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? AppColors.accentPrimary : AppColors.cardBorder,
                    width: isRetroMode ? 2.0 : (sel ? 2.0 : 1.0),
                  ),
                  boxShadow: isRetroMode && sel
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          opt.icon,
                          size: 16,
                          color: sel
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accentPrimary
                                : Colors.transparent,
                            borderRadius: isRetroMode
                                ? BorderRadius.zero
                                : BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? AppColors.accentPrimary
                                  : AppColors.cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: sel
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 10,
                                  color: isRetroMode && !AppColors.isDark
                                      ? AppColors.textPrimary
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      opt.label,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: isRetroMode ? 10 : 13,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? AppColors.accentPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opt.desc,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: isRetroMode ? 9 : 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppearanceToggle(bool isRetroMode, bool isDark) {
    return Container(
      height: isRetroMode ? 50 : 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: isRetroMode
            ? BorderRadius.zero
            : BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.cardBorder,
          width: isRetroMode ? 2.0 : 1.0,
        ),
        boxShadow: isRetroMode
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
        children: [
          _buildAppearanceOption(
            isRetroMode,
            'Light',
            Icons.light_mode_rounded,
            !isDark,
            () {
              HapticFeedback.selectionClick();
              ref.read(themeModeProvider.notifier).setDark(false);
            },
          ),
          _buildAppearanceOption(
            isRetroMode,
            'Dark',
            Icons.dark_mode_rounded,
            isDark,
            () {
              HapticFeedback.selectionClick();
              ref.read(themeModeProvider.notifier).setDark(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceOption(
    bool isRetroMode,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final fg = isSelected
        ? (isRetroMode && !AppColors.isDark
              ? AppColors.textPrimary
              : Colors.white)
        : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentPrimary : Colors.transparent,
            borderRadius: isRetroMode
                ? BorderRadius.zero
                : BorderRadius.circular(10),
            border: isSelected && isRetroMode
                ? Border.all(color: AppColors.cardBorder, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.buttonLabel.copyWith(
                    color: fg,
                    fontSize: isRetroMode ? 9 : 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Page 3: Profile Setup ──────────────────────────────────────────────────
  Widget _buildProfilePage(bool isRetro) {
    return _animated(
      3,
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Let's set up\nyour profile.",
              style: isRetro
                  ? RetroTypography.displayHeading.copyWith(
                      fontSize: 15,
                      height: 1.3,
                    )
                  : AppTypography.displayHeading.copyWith(
                      fontSize: 26,
                      height: 1.25,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose an avatar and tell us what to call you.',
              style: isRetro
                  ? RetroTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    )
                  : AppTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
            ),
            const SizedBox(height: 24),

            Text(
              'YOUR NAME',
              style: isRetro
                  ? RetroTypography.sectionLabel.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.0,
                    )
                  : AppTypography.sectionLabel.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                    ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isRetro
                    ? AppColors.inputBackground
                    : AppColors.cardBackground,
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: isRetro ? 2.0 : 1.0,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: isRetro
                    ? RetroTypography.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      )
                    : AppTypography.bodyText.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'e.g. Alex',
                  hintStyle: isRetro
                      ? RetroTypography.bodyText.copyWith(
                          color: AppColors.textPlaceholder,
                          fontSize: 13,
                        )
                      : AppTypography.bodyText.copyWith(
                          color: AppColors.textPlaceholder,
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'PICK AN AVATAR',
              style: isRetro
                  ? RetroTypography.sectionLabel.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.0,
                    )
                  : AppTypography.sectionLabel.copyWith(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                    ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kAvatarIcons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
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
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isRetro
                              ? AppColors.accentPrimary
                              : AppColors.accentPrimary.withValues(
                                  alpha: 0.14,
                                ))
                          : (isRetro
                              ? AppColors.inputBackground
                              : AppColors.cardBackground),
                      borderRadius: isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(12),
                      border: Border.all(
                        color: isRetro
                            ? AppColors.cardBorder
                            : (isSelected
                                ? AppColors.accentPrimary
                                : Colors.white.withValues(alpha: 0.08)),
                        width: isRetro ? 2.0 : (isSelected ? 2.0 : 1.0),
                      ),
                      boxShadow: isRetro
                          ? [
                              BoxShadow(
                                color: AppColors.retroShadowColor,
                                offset: isSelected
                                    ? const Offset(2, 2)
                                    : const Offset(1.5, 1.5),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        kAvatarIcons[index],
                        size: 22,
                        color: isSelected
                            ? (isRetro
                                ? (AppColors.isDark
                                    ? const Color(0xFF191920)
                                    : AppColors.textPrimary)
                                : AppColors.accentPrimary)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 4: Permissions ────────────────────────────────────────────────────
  Widget _buildPermissionsPage(bool isRetro) {
    return _animated(
      4,
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon
            TweenAnimationBuilder<double>(
              key: ValueKey('perm_icon_$_currentPage'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.cardBackground
                      : AppColors.warningTag.withValues(alpha: 0.12),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(14),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : AppColors.warningTag.withValues(alpha: 0.35),
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
                child: Icon(
                  Icons.shield_outlined,
                  size: 26,
                  color: isRetro && !AppColors.isDark
                      ? const Color(0xFF996500)
                      : AppColors.warningTag,
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'A few permissions.',
              style: AppTypography.displayHeading.copyWith(
                fontSize: isRetro ? 17 : 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Momentum needs these to work seamlessly. You can skip any and configure them later in Settings.',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: isRetro ? 11 : 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // 1. Notifications permission card
            _buildPermissionCard(
              isRetro: isRetro,
              icon: Icons.notifications_active_outlined,
              color: AppColors.accentPrimary,
              title: 'Notifications',
              description:
                  'Daily routine alerts, habit reminders, and end-of-day momentum check-ins.',
              status: _notifStatus,
              opensSettings: false,
              onGrant: _requestNotifications,
            ),

            const SizedBox(height: 12),

            // 2. Focus Shield (Accessibility) permission card
            _buildPermissionCard(
              isRetro: isRetro,
              icon: Icons.shield_outlined,
              color: AppColors.successDone,
              title: 'Focus Shield',
              description:
                  'App blocker accessibility service to shield your routines from distracting apps.',
              status: _shieldStatus,
              opensSettings: true,
              onGrant: _requestShield,
            ),

            const SizedBox(height: 12),

            // 3. Do Not Disturb permission card
            _buildPermissionCard(
              isRetro: isRetro,
              icon: Icons.do_not_disturb_on_outlined,
              color: AppColors.warningTag,
              title: 'Do Not Disturb',
              description:
                  'Automatically silences ringtones & notifications while deep focus tasks run.',
              status: _dndStatus,
              opensSettings: true,
              onGrant: _requestDnd,
            ),

            const SizedBox(height: 20),

            if (_shieldStatus != _PermStatus.granted) ...[
              const RestrictedSettingsHelp(),
              const SizedBox(height: 20),
            ],

            // Offline notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(12),
                border: Border.all(
                  color: isRetro
                      ? AppColors.cardBorder
                      : AppColors.subtleBorder,
                  width: isRetro ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Momentum is 100% offline. No analytics, tracking, or network access.',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textMuted,
                        fontSize: isRetro ? 8.5 : 11,
                        height: 1.35,
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

  Widget _buildPermissionCard({
    required bool isRetro,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required _PermStatus status,
    required bool opensSettings,
    required VoidCallback onGrant,
  }) {
    final isGranted = status == _PermStatus.granted;
    final isRequesting = status == _PermStatus.requesting;
    final isDenied = status == _PermStatus.denied;

    final isDark = AppColors.isDark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(15),
        border: Border.all(
          color: isRetro
              ? AppColors.cardBorder
              : (isGranted
                    ? AppColors.successDone.withValues(alpha: 0.4)
                    : color.withValues(alpha: 0.2)),
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
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isGranted
                      ? (isRetro
                            ? (isDark
                                  ? const Color(0xFF26382B)
                                  : const Color(0xFFD6EBD8))
                            : AppColors.successDone.withValues(alpha: 0.15))
                      : (isRetro
                            ? (isDark
                                  ? color.withValues(alpha: 0.22)
                                  : color.withValues(alpha: 0.15))
                            : color.withValues(alpha: 0.12)),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  border: isRetro
                      ? Border.all(color: AppColors.cardBorder, width: 1.5)
                      : null,
                ),
                child: Icon(
                  isGranted ? Icons.check_rounded : icon,
                  size: 20,
                  color: isGranted
                      ? (isRetro && !isDark
                            ? const Color(0xFF1E5E28)
                            : AppColors.successDone)
                      : (isRetro && !isDark && color == AppColors.warningTag
                            ? const Color(0xFF996500)
                            : color),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: AppTypography.cardTitle.copyWith(
                            fontSize: isRetro ? 10.5 : 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (opensSettings && !isGranted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRetro
                                  ? (isDark
                                        ? AppColors.inputBackground
                                        : const Color(0xFFDDD6C1))
                                  : AppColors.inputBackground,
                              borderRadius: isRetro
                                  ? BorderRadius.zero
                                  : BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.cardBorder,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              'Settings',
                              style: AppTypography.tagChip.copyWith(
                                fontSize: isRetro ? 7 : 8.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: isRetro ? 9.5 : 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: isGranted
                ? _buildGrantedBadge(isRetro)
                : isDenied
                ? _buildRetryButton(isRetro, color, onGrant)
                : _buildGrantButton(
                    isRetro,
                    color,
                    isRequesting,
                    opensSettings,
                    onGrant,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantedBadge(bool isRetro) {
    final isDark = AppColors.isDark;

    if (isRetro) {
      final badgeBg = isDark
          ? const Color(0xFF26382B)
          : const Color(0xFFD6EBD8);
      final badgeFg = isDark
          ? RetroDarkColors.greenSuccess
          : const Color(0xFF1E5E28);

      return Container(
        height: 36,
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, size: 14, color: badgeFg),
            const SizedBox(width: 6),
            Text(
              'Permission Granted',
              style: AppTypography.buttonLabel.copyWith(
                color: badgeFg,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.successDone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.successDone.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_rounded, size: 15, color: AppColors.successDone),
          const SizedBox(width: 6),
          Text(
            'Permission Granted',
            style: AppTypography.buttonLabel.copyWith(
              color: AppColors.successDone,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantButton(
    bool isRetro,
    Color color,
    bool isRequesting,
    bool opensSettings,
    VoidCallback onGrant,
  ) {
    return isRetro
        ? _RetroPermButton(
            label: opensSettings ? 'Open Settings →' : 'Grant Access',
            color: color,
            isLoading: isRequesting,
            onTap: onGrant,
          )
        : SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: isRequesting ? null : onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: BorderSide(
                    color: color.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
              ),
              child: isRequesting
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (opensSettings) ...[
                          const Icon(Icons.open_in_new_rounded, size: 13),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            opensSettings ? 'Open Settings' : 'Grant Access',
                            textAlign: TextAlign.center,
                            style: AppTypography.buttonLabel.copyWith(
                              color: color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
  }

  Widget _buildRetryButton(bool isRetro, Color color, VoidCallback onGrant) {
    if (isRetro) {
      return _RetroPermButton(
        label: 'Retry Permission',
        color: AppColors.errorAlert,
        isLoading: false,
        onTap: onGrant,
      );
    }
    return GestureDetector(
      onTap: onGrant,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.errorAlert.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: AppColors.errorAlert.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 13, color: AppColors.errorAlert),
            const SizedBox(width: 6),
            Text(
              'Try Again',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.errorAlert,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 5: All Set ────────────────────────────────────────────────────────
  Widget _buildReadyPage(bool isRetro) {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'there';

    final grantedCount = [
      _notifStatus,
      _shieldStatus,
      _dndStatus,
    ].where((s) => s == _PermStatus.granted).length;

    return _animated(
      5,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              key: ValueKey('ready_icon_$_currentPage'),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: _reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.successDone
                      : AppColors.successDone.withValues(alpha: 0.12),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(20),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : AppColors.successDone.withValues(alpha: 0.35),
                    width: isRetro ? 2.0 : 1.5,
                  ),
                  boxShadow: isRetro
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: isRetro
                        ? (AppColors.isDark
                            ? const Color(0xFF191920)
                            : Colors.white)
                        : AppColors.successDone,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              "You're all set,\n$name! 🎉",
              textAlign: TextAlign.center,
              style: isRetro
                  ? RetroTypography.displayHeading.copyWith(
                      fontSize: 15,
                      height: 1.3,
                    )
                  : AppTypography.displayHeading.copyWith(
                      fontSize: 28,
                      height: 1.25,
                    ),
            ),

            const SizedBox(height: 10),

            Text(
              'Your daily dashboard is ready. Build routines, track your money, and start logging momentum.',
              textAlign: TextAlign.center,
              style: isRetro
                  ? RetroTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.45,
                    )
                  : AppTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.55,
                    ),
            ),

            if (grantedCount < 3) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.cardBackground
                      : AppColors.warningTag.withValues(alpha: 0.08),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(12),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : AppColors.warningTag.withValues(alpha: 0.25),
                    width: isRetro ? 2.0 : 1.0,
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
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isRetro
                          ? (AppColors.isDark
                              ? AppColors.warningTag
                              : const Color(0xFFB45309))
                          : AppColors.warningTag,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${3 - grantedCount} permission(s) skipped. You can enable them anytime in Settings.',
                        style: isRetro
                            ? RetroTypography.bodyText.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 10,
                                height: 1.4,
                              )
                            : AppTypography.bodyText.copyWith(
                                color: AppColors.warningTag,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRetro
                      ? AppColors.cardBackground
                      : AppColors.successDone.withValues(alpha: 0.08),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(12),
                  border: Border.all(
                    color: isRetro
                        ? AppColors.cardBorder
                        : AppColors.successDone.withValues(alpha: 0.25),
                    width: isRetro ? 2.0 : 1.0,
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
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.successDone,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All permissions configured! Momentum is ready for deep work.',
                        style: isRetro
                            ? RetroTypography.bodyText.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 10,
                                height: 1.4,
                              )
                            : AppTypography.bodyText.copyWith(
                                color: AppColors.successDone,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildReadyCard(
                    isRetro,
                    Icons.lock_open_outlined,
                    'Privacy',
                    'Fully\noffline-first',
                    AppColors.successDone,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadyCard(
                    isRetro,
                    Icons.bolt_rounded,
                    'Momentum',
                    'Start your\nfirst routine',
                    AppColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyCard(
    bool isRetro,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(12),
        border: Border.all(
          color: isRetro ? AppColors.cardBorder : color.withValues(alpha: 0.2),
          width: isRetro ? 2.0 : 1.0,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isRetro
                  ? AppColors.inputBackground
                  : color.withValues(alpha: 0.12),
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(7),
              border: isRetro
                  ? Border.all(color: AppColors.cardBorder, width: 1.5)
                  : null,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: isRetro
                ? RetroTypography.cardTitle.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  )
                : AppTypography.cardTitle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 8.5,
                    height: 1.35,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Controls ────────────────────────────────────────────────────────
  Widget _buildBottomControls(bool isRetro, bool isCarousel) {
    final isLastPage = _currentPage == _totalSteps - 1;

    final buttonLabel = isLastPage
        ? 'Launch Momentum'
        : (_currentPage == 3
              ? 'Continue'
              : (_currentPage == 4
                    ? 'Continue'
                    : (_currentPage == 0 ? 'Get Started' : 'Next')));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCarousel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselCount, (index) {
                final isActive = _currentPage == index;
                return GestureDetector(
                  onTap: () => _goToPage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? (isRetro ? 22 : 24) : (isRetro ? 8 : 7),
                    height: isRetro ? 8 : 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accentPrimary
                          : (isRetro
                                ? AppColors.inputBackground
                                : AppColors.textPlaceholder.withValues(
                                    alpha: 0.3,
                                  )),
                      borderRadius: isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(4),
                      border: isRetro
                          ? Border.all(color: AppColors.cardBorder, width: 1.0)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
          _buildCtaButton(isRetro, buttonLabel),
        ],
      ),
    );
  }

  Widget _buildCtaButton(bool isRetro, String label) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isRetro
          ? _RetroCtaButton(label: label, isSaving: _isSaving, onTap: _nextPage)
          : ElevatedButton(
              onPressed: _isSaving ? null : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '$label →',
                      style: AppTypography.buttonLabel.copyWith(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
    );
  }
}

// ── Retro Permission Grant Button ─────────────────────────────────────────────
class _RetroPermButton extends StatefulWidget {
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _RetroPermButton({
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_RetroPermButton> createState() => _RetroPermButtonState();
}

class _RetroPermButtonState extends State<_RetroPermButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final fgColor = AppColors.isDark
        ? const Color(0xFF191920)
        : AppColors.textPrimary;

    return GestureDetector(
      onTapDown: widget.isLoading
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isLoading
          ? null
          : (_) {
              setState(() => _isPressed = false);
              HapticFeedback.selectionClick();
              widget.onTap();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(
          _isPressed ? 2.0 : 0.0,
          _isPressed ? 2.0 : 0.0,
          0.0,
        ),
        height: 36,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.cardBorder, width: 2.0),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: AppColors.retroShadowColor,
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: widget.isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: fgColor,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.label,
                  style: AppTypography.buttonLabel.copyWith(
                    color: fgColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Retro CTA Button ──────────────────────────────────────────────────────────
class _RetroCtaButton extends StatefulWidget {
  final String label;
  final bool isSaving;
  final VoidCallback onTap;

  const _RetroCtaButton({
    required this.label,
    required this.isSaving,
    required this.onTap,
  });

  @override
  State<_RetroCtaButton> createState() => _RetroCtaButtonState();
}

class _RetroCtaButtonState extends State<_RetroCtaButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final fgColor = AppColors.isDark
        ? const Color(0xFF191920)
        : AppColors.textPrimary;

    return GestureDetector(
      onTapDown: widget.isSaving
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isSaving
          ? null
          : (_) {
              setState(() => _isPressed = false);
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(
          _isPressed ? 3.0 : 0.0,
          _isPressed ? 3.0 : 0.0,
          0.0,
        ),
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.isSaving
              ? AppColors.accentPrimary.withValues(alpha: 0.6)
              : AppColors.accentPrimary,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.cardBorder, width: 2.0),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: AppColors.retroShadowColor,
                    offset: const Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: widget.isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: fgColor,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  '${widget.label} →',
                  style: AppTypography.buttonLabel.copyWith(
                    color: fgColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
