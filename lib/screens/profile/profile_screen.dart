import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- Added URL Launcher
import '../../models/user_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../constants/avatar_icons.dart';
import '../../services/notification_service.dart';
import '../onboarding/onboarding_screen.dart';
import '../routine/routine_builder_screen.dart';
import 'help_screen.dart';

final userSettingsProvider = Provider<UserSettings>((ref) {
  final box = Hive.box<UserSettings>('userSettings');
  return box.get('user') ?? UserSettings();
});

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
    final settings =
        Hive.box<UserSettings>('userSettings').get('user') ?? UserSettings();
    _avatarIndex = settings.avatarIndex;
    _displayName = settings.firstName.isEmpty ? 'You' : settings.firstName;
  }

  String _formatEodTime() {
    final h = _eodTime.hour;
    final m = _eodTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return 'Daily $hour:$m $period';
  }

  void _openEditProfileSheet() {
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
    );
  }

  void _openNotificationsModal() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eodTime,
      helpText: 'SET EOD REMINDER TIME',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            surface: Color(0xFF121217),
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
            content: Text('EOD reminder set for ${picked.format(context)}'),
            backgroundColor: AppColors.successDone,
          ),
        );
      }
    }
  }

  Future<void> _wipeData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121217),
        title: Text(
          'Wipe all data?',
          style: AppTypography.displayHeading.copyWith(fontSize: 18),
        ),
        content: Text(
          'This will permanently delete all tasks, logs, and wallet data. This cannot be undone.',
          style: AppTypography.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'WIPE',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.errorAlert,
              ),
            ),
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

  // ─── NEW: About Dialog Method ────────────────────────────────────────────────
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121217),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1A1A24)),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/icon/Momentum_appIcon.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Momentum',
                style: AppTypography.displayHeading.copyWith(fontSize: 20),
              ),
            ],
          ),
          content: Text(
            'Momentum is a personal Life OS designed to help you build consistent routines, track daily habits, and manage your financial baseline.\n\nKeep your momentum going.',
            style: AppTypography.bodyText.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Inline Header ─────────────────────────────────────────────
              Text(
                'SETTINGS',
                style: AppTypography.sectionLabel.copyWith(
                  color: AppColors.accentPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text('Profile & App', style: AppTypography.displayHeading),
              const SizedBox(height: 36),

              // ── Identity Profile ──────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient glow behind avatar
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentPrimary.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        // Avatar container
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accentPrimary.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            kAvatarIcons[_avatarIndex],
                            color: AppColors.accentPrimary,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _openEditProfileSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161619),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF1E1E26)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _displayName,
                              style: AppTypography.displayHeading.copyWith(fontSize: 17),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // ── Routine & Schedule ────────────────────────────────────────
              const _SectionHeader('ROUTINE & SCHEDULE'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121217),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A24)),
                ),
                child: _SettingsRow(
                  icon: Icons.edit_calendar_outlined,
                  iconColor: const Color(0xFFE8A01A),
                  iconBg: const Color(0xFFE8A01A).withValues(alpha: 0.12),
                  label: 'Edit Routine',
                  subtitle: 'Change tasks and blocks',
                  onTap: _openEditRoutine,
                ),
              ),

              // ── App Settings ──────────────────────────────────────────────
              const SizedBox(height: 32),
              const _SectionHeader('APP SETTINGS'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121217),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A24)),
                ),
                child: _SettingsRow(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFF1A6FE8),
                  iconBg: const Color(0xFF1A6FE8).withValues(alpha: 0.12),
                  label: 'EOD Reminder Time',
                  subtitle: _formatEodTime(),
                  onTap: _openNotificationsModal,
                ),
              ),

              // ── Support & Guides ──────────────────────────────────────────
              const SizedBox(height: 32),
              const _SectionHeader('SUPPORT'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121217),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A24)),
                ),
                child: _SettingsRow(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF9B6FE8),
                  iconBg: const Color(0xFF9B6FE8).withValues(alpha: 0.12),
                  label: 'Help & Feature Guide',
                  subtitle: 'Learn how every feature works',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  ),
                ),
              ),

              // ── About Momentum ────────────────────────────────────────────
              const SizedBox(height: 32),
              const _SectionHeader('ABOUT MOMENTUM'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121217),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A24)),
                ),
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.textPrimary,
                      iconBg: const Color(0xFF1E1E26),
                      label: 'What is Momentum?',
                      onTap: () => _showAboutDialog(context),
                    ),
                    const Divider(color: Color(0xFF1A1A24), height: 1, indent: 64),
                    _SettingsRow(
                      icon: Icons.code_rounded,
                      iconColor: AppColors.textPrimary,
                      iconBg: const Color(0xFF1E1E26),
                      label: 'App Version',
                      subtitle: 'Version 1.0.0',
                      showChevron: false,
                    ),
                  ],
                ),
              ),

              // ── Data Management ───────────────────────────────────────────
              const SizedBox(height: 32),
              const _SectionHeader('DANGER ZONE'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121217),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1A1A24)),
                ),
                child: _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.errorAlert,
                  iconBg: AppColors.errorAlert.withValues(alpha: 0.12),
                  label: 'Wipe App Data',
                  textColor: AppColors.errorAlert,
                  subtitle: 'Permanently delete all logs and history',
                  onTap: _wipeData,
                ),
              ),

              const SizedBox(height: 56),

              // ── Developer Signature ────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Designed & Built by Shaswata Das',
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textSecondary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        child: Text(
                          '@Shaswata28',
                          style: AppTypography.bodyText.copyWith(
                            color: const Color(0xFF555568),
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
}

// ─── Edit Profile Bottom Sheet ────────────────────────────────────────────────

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
  late TextEditingController _nameCtrl;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selected = widget.initialAvatar;
  }

  Future<void> _save() async {
    final box = Hive.box<UserSettings>('userSettings');
    final current = box.get('user') ?? UserSettings();
    await box.put(
      'user',
      UserSettings(
        firstName: _nameCtrl.text.trim(),
        avatarIndex: _selected,
        isFirstLaunch: current.isFirstLaunch,
      ),
    );
    widget.onSaved(_nameCtrl.text.trim(), _selected);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
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
          Text(
            'Edit Profile',
            style: AppTypography.displayHeading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 24),
          Text('FIRST NAME', style: AppTypography.sectionLabel),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121217),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A1A24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Your name',
                hintStyle: AppTypography.bodyText.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('AVATAR', style: AppTypography.sectionLabel),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(kAvatarIcons.length, (i) {
              final sel = _selected == i;
              return GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.accentPrimary.withValues(alpha: 0.15)
                        : const Color(0xFF121217),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? AppColors.accentPrimary
                          : const Color(0xFF1A1A24),
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
          const SizedBox(height: 28),
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
                'Save Profile',
                style: AppTypography.buttonLabel.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppTypography.sectionLabel.copyWith(
          color: const Color(0xFF666678),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBg;
  final Color? textColor;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor,
    this.iconBg,
    this.textColor,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.textPrimary;
    final fgIcon = iconColor ?? const Color(0xFF9A9AB0);
    final bgIcon = iconBg ?? const Color(0xFF1E1E26);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) onTap!();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgIcon,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: fgIcon, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyText.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF4A4A5A), size: 20),
          ],
        ),
      ),
    );
  }
}
