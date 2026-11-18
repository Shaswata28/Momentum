import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../widgets/app_back_button.dart';

enum LegalDoc { privacy, terms }

class LegalScreen extends StatelessWidget {
  final LegalDoc doc;

  const LegalScreen({
    super.key,
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final isPrivacy = doc == LegalDoc.privacy;

    final title = isPrivacy
        ? (isRetro ? 'PRIVACY POLICY' : 'Privacy Policy')
        : (isRetro ? 'TERMS OF SERVICE' : 'Terms of Service');

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Center(child: AppBackButton()),
        ),
        title: Text(
          title,
          style: isRetro
              ? RetroTypography.displayHeading.copyWith(fontSize: 13)
              : AppTypography.displayHeading.copyWith(
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        children: [
          if (isPrivacy)
            ..._buildPrivacyContent(isRetro)
          else
            ..._buildTermsContent(isRetro),
        ],
      ),
    );
  }

  List<Widget> _buildPrivacyContent(bool isRetro) {
    return [
      _buildBadgeBanner(
        icon: Icons.lock_outline_rounded,
        title: isRetro ? '100% OFFLINE-FIRST' : '100% Offline-First Architecture',
        subtitle: 'Momentum collects zero personal data. All routines, tasks, and wallet transactions are stored strictly on your local device.',
        isRetro: isRetro,
      ),
      const SizedBox(height: 20),

      _buildCard(
        icon: Icons.storage_rounded,
        title: 'Local Storage & Data Ownership',
        body:
            '• All data is stored locally in device storage via Hive database.\n'
            '• There are no cloud servers, external databases, or remote backups hosted by Momentum.\n'
            '• You have 100% complete ownership over your data. If you wipe data or uninstall the application, all stored records are erased permanently from your device.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.shield_rounded,
        title: 'AccessibilityService API Disclosure',
        body:
            'Momentum utilizes the Android AccessibilityService API strictly for its optional Focus Shield (App Blocker) feature.\n\n'
            '• Purpose: To detect when user-selected distracting apps are launched during an active Focus Session, displaying the Mindful Friction screen.\n'
            '• Privacy Commitment: Momentum NEVER observes, captures, logs, stores, or transmits your screen content, typed keystrokes, personal messages, or credentials.\n'
            '• Control: This service can be enabled or disabled at any time in Settings > Focus Shield.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.alarm_rounded,
        title: 'Alarms & Notification Permissions',
        body:
            '• Exact Alarms (USE_EXACT_ALARM / SCHEDULE_EXACT_ALARM): Required to trigger on-time task notifications, End-of-Day reminders, and scheduled bill alerts.\n'
            '• Notifications: Used solely for local system alerts. No push notification servers or marketing pings are ever utilized.\n'
            '• Do Not Disturb (DND): Used optionally during active focus tasks to minimize digital interruptions.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.block_rounded,
        title: 'Zero Tracking & Third-Party SDKs',
        body:
            '• Momentum contains NO third-party advertising frameworks (e.g. AdMob).\n'
            '• Momentum contains NO analytics or telemetry trackers (e.g. Firebase Analytics, Facebook SDK).\n'
            '• No user profiles, device identifiers, or usage logs are sent to anyone.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.contact_support_outlined,
        title: 'Developer Contact & Questions',
        body:
            'For any questions or privacy concerns regarding Momentum v2.0, please reach out via GitHub:\n\n'
            'https://github.com/Shaswata28',
        isRetro: isRetro,
      ),
    ];
  }

  List<Widget> _buildTermsContent(bool isRetro) {
    return [
      _buildBadgeBanner(
        icon: Icons.gavel_rounded,
        title: isRetro ? 'TERMS OF SERVICE' : 'Terms & Conditions of Use',
        subtitle: 'By using Momentum, you agree to these simple terms governing personal, offline use.',
        isRetro: isRetro,
      ),
      const SizedBox(height: 20),

      _buildCard(
        icon: Icons.verified_user_outlined,
        title: '1. Personal Use License',
        body:
            'Momentum grants you a personal, non-transferable, non-exclusive license to use the application on your personal Android device solely for self-tracking, habit building, and personal budgeting.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.account_balance_wallet_outlined,
        title: '2. Financial & Medical Disclaimer',
        body:
            '• Not Financial Advice: The wallet and budgeting features provided by Momentum are designed strictly for personal note-taking and tracking. Momentum does not offer accounting, investment, tax, or certified financial advice.\n\n'
            '• Not Health/Medical Advice: The routine, hydration, and habit tracking tools are self-management utilities and do not substitute for professional medical or mental health care.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.cloud_off_rounded,
        title: '3. Data Responsibility & Loss',
        body:
            'Because Momentum is an offline-first app, you are solely responsible for managing your device storage.\n\n'
            '• We cannot recover lost data if you uninstall the app, wipe your device, or clear app storage.\n'
            '• We recommend utilizing any available system-level device backups if you intend to preserve your data across phone migrations.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.security_rounded,
        title: '4. "As-Is" Warranty & Liability',
        body:
            'Momentum is provided "as is" and "as available" without warranties of any kind, whether express or implied. Under no circumstances will the developer be liable for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use this app.',
        isRetro: isRetro,
      ),

      _buildCard(
        icon: Icons.update_rounded,
        title: '5. Updates & Governing Law',
        body:
            'These terms and the application features may be updated from time to time with app releases. Continued use of Momentum after updates constitutes acceptance of the modified terms.',
        isRetro: isRetro,
      ),
    ];
  }

  Widget _buildBadgeBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isRetro,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isRetro
            ? AppColors.cardBackground
            : AppColors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(16),
        border: Border.all(
          color: isRetro
              ? AppColors.cardBorder
              : AppColors.accentPrimary.withValues(alpha: 0.25),
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
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isRetro
                  ? AppColors.accentPrimary
                  : AppColors.accentPrimary.withValues(alpha: 0.15),
              borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(12),
              border: isRetro
                  ? Border.all(color: AppColors.cardBorder, width: 2.0)
                  : null,
            ),
            child: Icon(
              icon,
              size: 24,
              color: isRetro && !AppColors.isDark
                  ? AppColors.textPrimary
                  : (isRetro ? Colors.black : AppColors.accentPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: isRetro
                      ? RetroTypography.displayHeading.copyWith(fontSize: 11)
                      : AppTypography.cardTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: isRetro
                      ? RetroTypography.bodyText.copyWith(
                          fontSize: 9.5,
                          color: AppColors.textSecondary,
                        )
                      : AppTypography.bodyText.copyWith(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
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

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String body,
    required bool isRetro,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder,
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
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: isRetro
                      ? RetroTypography.displayHeading.copyWith(fontSize: 10.5)
                      : AppTypography.cardTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 9.5,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
          ),
        ],
      ),
    );
  }
}
