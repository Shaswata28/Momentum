import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_settings.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../constants/avatar_icons.dart';
import '../../services/notification_service.dart';
import '../../widgets/action_button.dart';
import '../../widgets/app_back_button.dart';
import '../onboarding/onboarding_screen.dart';
import '../routine/routine_builder_screen.dart';
import '../wallet/wallet_settings_sheet.dart';
import 'help_screen.dart';
import 'app_blocker_settings_screen.dart';
import 'legal_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  late int _avatarIndex;
  late String _displayName;
  TimeOfDay _eodTime = const TimeOfDay(hour: 22, minute: 30);
  bool _savingReminder = false;
  bool? _reminderScheduled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings =
        Hive.box<UserSettings>('userSettings').get('user') ?? UserSettings();
    _avatarIndex = settings.avatarIndex;
    _displayName = settings.firstName.isEmpty ? 'You' : settings.firstName;
    _eodTime = NotificationService().savedEODReminder;
    _refreshReminder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshReminder();
  }

  Future<void> _refreshReminder() async {
    final scheduled = await NotificationService().scheduleEODPrompt();
    if (mounted) setState(() => _reminderScheduled = scheduled);
  }

  String _formatEodTime() {
    final h = _eodTime.hour;
    final m = _eodTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }

  void _openEditProfileSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        initialName: _displayName == 'You' ? '' : _displayName,
        initialAvatar: _avatarIndex,
        onSaved: (name, avatar) {
          setState(() {
            _displayName = name.isEmpty ? 'You' : name;
            _avatarIndex = avatar;
          });
        },
      ),
    );
  }

  void _openEditRoutine() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
    );
  }

  void _openWalletSettings() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WalletSettingsSheet(),
    );
  }

  void _openNotificationsModal() async {
    if (_savingReminder) return;
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _eodTime,
      helpText: 'SET EOD REMINDER TIME',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.accentPrimary,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _savingReminder = true);
      try {
        final scheduled = await NotificationService().saveEODReminder(picked);
        if (!mounted) return;
        setState(() {
          _eodTime = picked;
          _reminderScheduled = scheduled;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scheduled
                  ? 'Daily reminder scheduled for ${picked.format(context)}'
                  : 'Time saved. Notifications are denied or unavailable; reminder is not active.',
            ),
          ),
        );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save reminder. Please try again.'),
            ),
          );
      } finally {
        if (mounted) setState(() => _savingReminder = false);
      }
    }
  }

  Future<void> _wipeData() async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppColors.isRetro
              ? BorderRadius.zero
              : BorderRadius.circular(18),
        ),
        title: Text(
          'Wipe all data?',
          style: AppTypography.displayHeading.copyWith(fontSize: 18),
        ),
        content: Text(
          'This will permanently delete all tasks, logs, wallet transactions, and preferences. This action cannot be undone.',
          style: AppTypography.bodyText.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Wipe Everything',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.errorAlert,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      await Hive.deleteFromDisk();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: AppColors.isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(18),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.subtleBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/icon/Momentum_appIcon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.accentPrimary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.flash_on_rounded,
                        size: 20,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Momentum',
                style: AppTypography.displayHeading.copyWith(
                  fontSize: AppColors.isRetro ? 16 : 20,
                ),
              ),
            ],
          ),
          content: Text(
            'Momentum is a calm personal Life OS designed to help you build consistent routines, track daily finances, and keep long-term momentum going without cognitive clutter.\n\n100% offline-first, local-only, and zero trackers.\n\nVersion 2.0.0',
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
              fontSize: AppColors.isRetro ? 11 : 13.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(doc: LegalDoc.privacy),
                  ),
                );
              },
              child: const Text('Privacy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(doc: LegalDoc.terms),
                  ),
                );
              },
              child: const Text('Terms'),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Momentum',
              ),
              child: const Text('Licenses'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: AppTypography.buttonLabel.copyWith(
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Apple Top Bar ──────────────────────────────────────────
              Row(
                children: [
                  if (Navigator.canPop(context))
                    const AppBackButton(
                      margin: EdgeInsets.only(right: 14),
                    ),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: AppTypography.displayHeading.copyWith(
                        fontSize: AppColors.isRetro ? 14 : 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Profile Hero Card ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: AppColors.isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: AppColors.isRetro ? 2.0 : 1.0,
                  ),
                  boxShadow: AppColors.isRetro
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openEditProfileSheet,
                    borderRadius: AppColors.isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentPrimary.withValues(
                                alpha: 0.15,
                              ),
                              border: Border.all(
                                color: AppColors.accentPrimary.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              kAvatarIcons[_avatarIndex],
                              color: AppColors.accentPrimary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: AppTypography.cardTitle.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to customize name & avatar',
                                  style: AppTypography.bodyText.copyWith(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.textPlaceholder,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Group 1: Routine & Schedule ────────────────────────────
              _buildSectionLabel('ROUTINE & SCHEDULE'),
              _buildGroupedCard([
                _SettingsTile(
                  icon: Icons.calendar_today_rounded,
                  iconColor: AppColors.accentPrimary,
                  title: 'Routine Builder',
                  subtitle: 'Manage recurring tasks and daily blocks',
                  onTap: _openEditRoutine,
                ),
                _SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.floatingTask,
                  title: 'EOD Reminder Time',
                  subtitle: _savingReminder
                      ? 'Saving reminder...'
                      : 'Daily at ${_formatEodTime()}\n${_reminderScheduled == true
                            ? 'Reminder active'
                            : _reminderScheduled == null
                            ? 'Checking notifications...'
                            : 'Time saved; notifications denied or unavailable'}',
                  onTap: _savingReminder ? null : _openNotificationsModal,
                ),
                if (_reminderScheduled == false)
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    iconColor: AppColors.accentPrimary,
                    title: 'Allow notifications',
                    subtitle:
                        'Android notification settings may need permission',
                    onTap: () async {
                      await NotificationService().requestPermissions();
                      await _refreshReminder();
                    },
                  ),
              ]),

              const SizedBox(height: 24),

              // ── Group 2: Focus & Shield ────────────────────────────────
              _buildSectionLabel('FOCUS & SHIELD'),
              _buildGroupedCard([
                _SettingsTile(
                  icon: Icons.shield_rounded,
                  iconColor: AppColors.accentPrimary,
                  title: 'Focus Shield & App Blocker',
                  subtitle: 'Block distracting apps during active DND tasks',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AppBlockerSettingsScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // ── Group 3: Wallet ────────────────────────────────────────
              _buildSectionLabel('WALLET & BUDGET'),
              _buildGroupedCard([
                _SettingsTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.adHocTask,
                  title: 'Wallet Settings',
                  subtitle: 'Opening balance, monthly budget & goals',
                  onTap: _openWalletSettings,
                ),
              ]),

              const SizedBox(height: 24),

              // ── Group 4: Appearance ────────────────────────────────────
              _buildSectionLabel('APPEARANCE'),
              _buildThemeSelector(),

              const SizedBox(height: 24),

              // ── Group 5: Support & About ────────────────────────────────
              _buildSectionLabel('SUPPORT & ABOUT'),
              _buildGroupedCard([
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: AppColors.successDone,
                  title: 'Help & Feature Guide',
                  subtitle: 'Learn how every feature works',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.textSecondary,
                  title: 'About Momentum',
                  subtitle: 'Philosophy & design',
                  onTap: () => _showAboutDialog(context),
                ),
                _SettingsTile(
                  icon: Icons.code_rounded,
                  iconColor: AppColors.textMuted,
                  title: 'App Version',
                  subtitle: '2.0.0',
                  showChevron: false,
                ),
              ]),

              const SizedBox(height: 24),

              // ── Group 5: Data & Privacy ────────────────────────────────
              _buildSectionLabel('DATA & PRIVACY'),
              _buildGroupedCard([
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.successDone,
                  title: 'Privacy Policy',
                  subtitle: '100% offline-first · Zero data collected',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(doc: LegalDoc.privacy),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: AppColors.accentPrimary,
                  title: 'Terms of Service',
                  subtitle: 'Usage guidelines & offline disclaimer',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(doc: LegalDoc.terms),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  iconColor: AppColors.errorAlert,
                  title: 'Wipe All Data',
                  titleColor: AppColors.errorAlert,
                  subtitle: 'Permanently reset all local data',
                  onTap: _wipeData,
                ),
              ]),

              const SizedBox(height: 48),

              // ── Signature Footer ───────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Momentum · Life Operating System',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textPlaceholder,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        final Uri url = Uri.parse(
                          'https://github.com/Shaswata28',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 16,
                        ),
                        child: Text(
                          '@Shaswata28',
                          style: AppTypography.bodyText.copyWith(
                            color: AppColors.textPlaceholder,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: AppTypography.sectionLabel.copyWith(
          fontSize: 11,
          letterSpacing: 1.0,
          color: AppColors.textPlaceholder,
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final currentMode = ref.watch(themeModeProvider);
    final isRetro = currentMode.isRetro;
    final isDark = (currentMode == AppThemeMode.system)
        ? AppColors.isDark
        : currentMode.isDark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppColors.isRetro
            ? BorderRadius.zero
            : BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppColors.isRetro ? 2.0 : 1.0,
        ),
        boxShadow: AppColors.isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Theme & Appearance',
                    style: isRetro
                        ? RetroTypography.titleLarge.copyWith(fontSize: 11)
                        : AppTypography.cardTitle.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── THEME (Classic | Retro) ───────────────────────────────────
          _buildThemeSectionLabel('THEME', Icons.brush_rounded),
          const SizedBox(height: 8),
          _buildSegmentedToggle(
            options: [
              (
                label: 'Classic',
                icon: Icons.auto_awesome_rounded,
                isSelected: !isRetro,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).setRetro(false);
                },
              ),
              (
                label: 'Retro',
                icon: Icons.videogame_asset_rounded,
                isSelected: isRetro,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).setRetro(true);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── APPEARANCE (Light | Dark) ─────────────────────────────────
          _buildThemeSectionLabel('APPEARANCE', Icons.contrast_rounded),
          const SizedBox(height: 8),
          _buildSegmentedToggle(
            options: [
              (
                label: 'Light',
                icon: Icons.light_mode_rounded,
                isSelected: !isDark && currentMode != AppThemeMode.system,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).setDark(false);
                },
              ),
              (
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                isSelected: isDark && currentMode != AppThemeMode.system,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).setDark(true);
                },
              ),
            ],
          ),
          if (!isRetro)
            Material(
              color: AppColors.cardBackground,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Use device appearance',
                  style: AppTypography.bodyText,
                ),
                value: currentMode == AppThemeMode.system,
                activeColor: AppColors.accentPrimary,
                onChanged: (value) => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(
                      value == true
                          ? AppThemeMode.system
                          : (AppColors.isDark
                                ? AppThemeMode.dark
                                : AppThemeMode.light),
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentedToggle({
    required List<
      ({String label, IconData icon, bool isSelected, VoidCallback onTap})
    >
    options,
  }) {
    final isRetroMode = AppColors.isRetro;

    return Container(
      height: isRetroMode ? 38 : 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetroMode
            ? BorderRadius.zero
            : BorderRadius.circular(10),
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
        children: options.map((opt) {
          final isSelected = opt.isSelected;

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: opt.onTap,
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isRetroMode
                            ? AppColors.accentPrimary.withValues(
                                alpha: AppColors.isDark ? 0.28 : 0.20,
                              )
                            : AppColors.accentPrimary.withValues(alpha: 0.15))
                        : Colors.transparent,
                    borderRadius: isRetroMode
                        ? BorderRadius.zero
                        : BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(
                            color: isRetroMode
                                ? AppColors.accentPrimary
                                : AppColors.accentPrimary.withValues(alpha: 0.6),
                            width: isRetroMode ? 1.5 : 1.0,
                          )
                        : Border.all(
                            color: Colors.transparent,
                            width: isRetroMode ? 1.5 : 1.0,
                          ),
                    boxShadow: (isRetroMode && isSelected)
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(1, 1),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opt.icon,
                            size: isRetroMode ? 13 : 15,
                            color: isSelected
                                ? AppColors.accentPrimary
                                : (isRetroMode
                                    ? AppColors.textMuted
                                    : AppColors.textSecondary),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isRetroMode ? opt.label.toUpperCase() : opt.label,
                            style: isRetroMode
                                ? RetroTypography.buttonLabel.copyWith(
                                    fontSize: 8.5,
                                    color: isSelected
                                        ? AppColors.accentPrimary
                                        : AppColors.textMuted,
                                  )
                                : AppTypography.buttonLabel.copyWith(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.accentPrimary
                                        : AppColors.textSecondary,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Small inline section header used inside the theme selector card.
  Widget _buildThemeSectionLabel(String label, IconData icon) {
    final isRetro = AppColors.isRetro;
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textPlaceholder),
        const SizedBox(width: 5),
        Text(
          label,
          style: isRetro
              ? RetroTypography.overline.copyWith(
                  fontSize: 7.5,
                  color: AppColors.textPlaceholder,
                  letterSpacing: 0.8,
                )
              : AppTypography.overline.copyWith(
                  fontSize: 9.5,
                  color: AppColors.textPlaceholder,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }

  Widget _buildGroupedCard(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppColors.isRetro
            ? BorderRadius.zero
            : BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppColors.isRetro ? 2.0 : 1.0,
        ),
        boxShadow: AppColors.isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: AppColors.isRetro
            ? BorderRadius.zero
            : BorderRadius.circular(16),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Divider(
                  height: 1,
                  thickness: AppColors.isRetro ? 2 : 1,
                  color: AppColors.dividerBorderHover,
                  indent: 58,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tile inside Apple-style grouped card ───────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitle.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textPlaceholder,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final int initialAvatar;
  final void Function(String name, int avatar) onSaved;

  const _EditProfileSheet({
    required this.initialName,
    required this.initialAvatar,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late int _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selected = widget.initialAvatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      HapticFeedback.mediumImpact();
      final box = Hive.box<UserSettings>('userSettings');
      final current = box.get('user') ?? UserSettings();
      await box.put(
        'user',
        UserSettings(
          firstName: _nameCtrl.text.trim(),
          avatarIndex: _selected,
          isFirstLaunch: current.isFirstLaunch,
          hasSeenCoachMarks: current.hasSeenCoachMarks,
        ),
      );
      if (!mounted) return;
      widget.onSaved(_nameCtrl.text.trim(), _selected);
      Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save profile. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: AppColors.isRetro
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          18,
          24,
          MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.subtleBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Edit Profile',
              style: AppTypography.displayHeading.copyWith(
                fontSize: AppColors.isRetro ? 16 : 20,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'FIRST NAME',
              style: AppTypography.sectionLabel.copyWith(
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.appBackground,
                borderRadius: AppColors.isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(12),
                border: Border.all(color: AppColors.subtleBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: _nameCtrl,
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Your name',
                  hintStyle: AppTypography.bodyText.copyWith(
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AVATAR',
              style: AppTypography.sectionLabel.copyWith(
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(kAvatarIcons.length, (i) {
                final sel = _selected == i;
                return Semantics(
                  button: true,
                  selected: sel,
                  label: 'Avatar ${i + 1}',
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = i);
                    },
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.accentPrimary.withValues(alpha: 0.18)
                            : AppColors.appBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel
                              ? AppColors.accentPrimary
                              : AppColors.subtleBorder,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        kAvatarIcons[i],
                        color: sel
                            ? AppColors.accentPrimary
                            : AppColors.textMuted,
                        size: 24,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 26),
            ActionButton(
              label: 'Save Changes',
              isPrimary: true,
              isLoading: _saving,
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
