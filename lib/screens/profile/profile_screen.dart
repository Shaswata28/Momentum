import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_settings.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../constants/avatar_icons.dart';
import '../../services/notification_service.dart';
import '../onboarding/onboarding_screen.dart';
import '../routine/routine_builder_screen.dart';
import '../wallet/wallet_settings_sheet.dart';
import 'help_screen.dart';
import 'app_blocker_settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late int _avatarIndex;
  late String _displayName;
  TimeOfDay _eodTime = const TimeOfDay(hour: 22, minute: 30);

  @override
  void initState() {
    super.initState();
    final settings = Hive.box<UserSettings>('userSettings').get('user') ?? UserSettings();
    _avatarIndex = settings.avatarIndex;
    _displayName = settings.firstName.isEmpty ? 'You' : settings.firstName;
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
    HapticFeedback.lightImpact();
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
      await NotificationService().rescheduleEODPrompt(picked);
      setState(() => _eodTime = picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EOD reminder scheduled for ${picked.format(context)}', style: AppTypography.bodyText),
            backgroundColor: AppColors.successDone,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _wipeData() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Wipe all data?',
          style: AppTypography.displayHeading.copyWith(fontSize: 18),
        ),
        content: Text(
          'This will permanently delete all tasks, logs, wallet transactions, and preferences. This action cannot be undone.',
          style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.buttonLabel.copyWith(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Wipe Everything', style: AppTypography.buttonLabel.copyWith(color: AppColors.errorAlert)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
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
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/icon/Momentum_appIcon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.accentPrimary.withValues(alpha: 0.15),
                      child: Icon(Icons.flash_on_rounded, size: 20, color: AppColors.accentPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('Momentum', style: AppTypography.displayHeading.copyWith(fontSize: 20)),
            ],
          ),
          content: Text(
            'Momentum is a calm personal Life OS designed to help you build consistent routines, track daily finances, and keep long-term momentum going without cognitive clutter.\n\nVersion 1.0.0',
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: AppTypography.buttonLabel.copyWith(color: AppColors.accentPrimary),
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
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                  Text('Settings', style: AppTypography.displayHeading.copyWith(fontSize: 28)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Profile Hero Card ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openEditProfileSheet,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentPrimary.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppColors.accentPrimary.withValues(alpha: 0.4),
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
                  subtitle: 'Daily at ${_formatEodTime()}',
                  onTap: _openNotificationsModal,
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
                      MaterialPageRoute(builder: (_) => const AppBlockerSettingsScreen()),
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
                  subtitle: '1.0.0',
                  showChevron: false,
                ),
              ]),

              const SizedBox(height: 24),

              // ── Group 5: Danger Zone ────────────────────────────────────
              _buildSectionLabel('DATA & PRIVACY'),
              _buildGroupedCard([
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
                        final Uri url = Uri.parse('https://github.com/Shaswata28');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

    final options = [
      (mode: ThemeMode.system, label: 'System', icon: Icons.brightness_auto_rounded),
      (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_rounded),
      (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Theme Mode',
                  style: AppTypography.cardTitle.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.subtleBorder),
            ),
            child: Row(
              children: options.map((opt) {
                final isSelected = currentMode == opt.mode;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(themeModeProvider.notifier).setThemeMode(opt.mode);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accentPrimary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            opt.icon,
                            size: 15,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            opt.label,
                            style: AppTypography.buttonLabel.copyWith(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCard(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
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
    widget.onSaved(_nameCtrl.text.trim(), _selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Edit Profile', style: AppTypography.displayHeading.copyWith(fontSize: 20)),
          const SizedBox(height: 20),
          Text(
            'FIRST NAME',
            style: AppTypography.sectionLabel.copyWith(fontSize: 11, letterSpacing: 1.0),
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
              controller: _nameCtrl,
              style: AppTypography.cardTitle.copyWith(color: AppColors.textPrimary),
              cursorColor: AppColors.accentPrimary,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Your name',
                hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textPlaceholder),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AVATAR',
            style: AppTypography.sectionLabel.copyWith(fontSize: 11, letterSpacing: 1.0),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(kAvatarIcons.length, (i) {
              final sel = _selected == i;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
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
                          : Colors.white.withValues(alpha: 0.08),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    kAvatarIcons[i],
                    color: sel ? AppColors.accentPrimary : AppColors.textMuted,
                    size: 24,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Save Changes',
                style: AppTypography.buttonLabel.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
