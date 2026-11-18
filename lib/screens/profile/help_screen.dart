import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../widgets/app_back_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Help & Feature Guide Screen — Momentum v2.0
// ─────────────────────────────────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

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
          isRetro ? 'FEATURE GUIDE v2.0' : 'Help & Feature Guide',
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
          // Intro
          const _Intro(),
          const SizedBox(height: 28),

          // ── 1. Routine & Tasks ─────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.repeat_rounded,
            label: 'ROUTINE & TASKS',
            color: AppColors.accentPrimary,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.construction_outlined,
            title: 'Building your weekly routine',
            body:
                'Head over to Settings > Routine Builder to craft your weekly routine! Use the 6-step task wizard to set repeating days, start times, durations, buffer intervals, and custom color tags.\n\n'
                'Momentum automatically generates your daily task timeline for you every morning based on what day it is.',
          ),
          const _HelpCard(
            icon: Icons.category_outlined,
            title: 'Fixed, Floating & Ad-hoc tasks',
            body:
                'Momentum separates your schedule into 3 task types:\n\n'
                '• Fixed Tasks: Anchored to specific clock times (e.g. 9:00 AM Meeting, Gym). Can trigger DND & Focus Shield.\n'
                '• Floating Tasks: Flexible daily habits with a set duration (e.g. 30 min Reading) that you can tackle anytime.\n'
                '• Ad-hoc Tasks: Quick, flexible check-ins without strict time bounds.',
          ),
          const _HelpCard(
            icon: Icons.add_circle_outline,
            title: 'Adding a quick temporary task',
            body:
                'Need to remember something just for today? Tap the "Add a task for today..." bar on your Today screen.\n\n'
                'It\'s perfect for one-off tasks like "Call plumber" or "Pick up parcel" that don\'t belong in your permanent weekly routine.',
          ),

          const SizedBox(height: 28),

          // ── 2. Wallet & Finance ────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.account_balance_wallet_outlined,
            label: 'WALLET & FINANCE',
            color: AppColors.successDone,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.tune_rounded,
            title: 'Setting up your Wallet & Budget',
            body:
                'To configure your finances, tap the tune icon at the top of the Wallet screen. '
                'Set your starting cash balance, define a Monthly Budget Limit to track against, '
                'and set a Semester Savings Target to visualize your savings milestones.',
          ),
          const _HelpCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Smart Category Auto-Detection',
            body:
                'When recording an income or expense, simply type in the note field (e.g. "uber", "coffee", "salary", "groceries", "dinner").\n\n'
                'Momentum automatically infers and selects the matching category for you in real-time!',
          ),
          const _HelpCard(
            icon: Icons.swap_horiz_rounded,
            title: 'Borrow & Lend Ledger',
            body:
                'Easily track money borrowed from or lent to colleagues and friends. '
                'Record the counterparty note, see net balances at a glance, and mark debts as settled with a single tap once repaid.',
          ),
          const _HelpCard(
            icon: Icons.receipt_long_outlined,
            title: 'Handling fixed bills & subscriptions',
            body:
                'Got rent, subscriptions, internet, or utilities? Add them to the Fixed Bills section.\n\n'
                'Each month, a single-tap "Pay" button records the payment instantly into your transaction ledger and marks the bill paid.',
          ),

          const SizedBox(height: 28),

          // ── 3. Focus & Shield ──────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.shield_outlined,
            label: 'FOCUS SHIELD & DND',
            color: AppColors.accentPrimary,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'How Focus Shield works',
            body:
                'Focus Shield automatically blocks distracting apps when you are inside an active DND task.\n\n'
                'If you open a blocked app, a calming mindful friction screen encourages you to pause and return to deep work, with 3 emergency passes per day.',
          ),
          const _HelpCard(
            icon: Icons.notifications_off_outlined,
            title: 'Automated Do Not Disturb (DND)',
            body:
                'When a task with DND enabled starts, Momentum automatically silences notifications and incoming alerts so you can stay in flow. DND turns off automatically when your task duration ends.',
          ),

          const SizedBox(height: 28),

          // ── 4. Themes & Retro Mode ─────────────────────────────────────────
          _GroupHeader(
            icon: Icons.videogame_asset_rounded,
            label: 'THEMES & RETRO MODE (v2.0)',
            color: AppColors.warningTag,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.palette_outlined,
            title: 'Retro 8-Bit Console Aesthetic',
            body:
                'Momentum v2.0 introduces an authentic retro console theme inspired by NES and Game Boy hardware!\n\n'
                'Featuring pixel fonts (Press Start 2P, Pixelify Sans, VT323), sharp 2.0px block borders, and authentic tactile offset shadows.',
          ),
          const _HelpCard(
            icon: Icons.brightness_medium_rounded,
            title: 'Light & Dark Palettes',
            body:
                'Choose your visual identity in Settings > Theme & Appearance:\n\n'
                '• Retro Light: Warm Beige Shell aesthetic (Game Boy / Famicom)\n'
                '• Retro Dark: Industrial Charcoal Console aesthetic (SNES / Game Boy Pocket)\n'
                '• Classic Mode: Clean, modern Things 3 inspired interface in Light or Graphite Dark.',
          ),

          const SizedBox(height: 28),

          // ── 5. Insights & Heatmap ──────────────────────────────────────────
          _GroupHeader(
            icon: Icons.insights_rounded,
            label: 'INSIGHTS & MOMENTUM',
            color: AppColors.floatingTask,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.nightlight_outlined,
            title: 'What does EOD mean?',
            body:
                'EOD stands for "End of Day". You can set your EOD Reminder Time in your profile settings.\n\n'
                'When it fires, you can rate your energy, motivation, budget adherence, and reflection notes in a fast 10-second check-in.',
          ),
          const _HelpCard(
            icon: Icons.grid_on_outlined,
            title: '35-day Consistency Heatmap',
            body:
                'Insights transforms your daily task completions and EOD logs into a 35-day visual heatmap showing your productivity streaks and energy cycles over time.',
          ),
          const _HelpCard(
            icon: Icons.speed_rounded,
            title: 'Safe Daily Spending & Pacing',
            body:
                'The Wallet tab in Insights calculates your Safe Daily Spending limit dynamically based on days remaining in the month and unallocated budget, ensuring you never run out before month end.',
          ),

          const SizedBox(height: 28),

          // ── 6. Data & Privacy ──────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.lock_outline_rounded,
            label: 'DATA & PRIVACY',
            color: AppColors.successDone,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.cloud_off_rounded,
            title: '100% Offline & Private',
            body:
                'Momentum requires no account, connects to no servers, and includes zero trackers or analytics.\n\n'
                'All routines, financial ledgers, and notes are encrypted and stored solely on your device storage via local Hive databases.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRetro
            ? AppColors.cardBackground
            : AppColors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(16),
        border: Border.all(
          color: isRetro
              ? AppColors.cardBorder
              : AppColors.accentPrimary.withValues(alpha: 0.2),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: AppColors.accentPrimary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Welcome to Momentum v2.0! Tap any topic below to expand it and discover all tools designed to help you stay in flow.',
              style: isRetro
                  ? RetroTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.45,
                    )
                  : AppTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section group header ──────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isRetro
                ? color
                : color.withValues(alpha: 0.12),
            borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(8),
            border: isRetro
                ? Border.all(color: AppColors.cardBorder, width: 1.5)
                : null,
          ),
          child: Icon(
            icon,
            color: isRetro ? Colors.white : color,
            size: 15,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: isRetro
                ? RetroTypography.sectionLabel.copyWith(
                    color: color,
                    fontSize: 9,
                  )
                : AppTypography.sectionLabel.copyWith(
                    color: color,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Expandable help card ──────────────────────────────────────────────────────
class _HelpCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  State<_HelpCard> createState() => _HelpCardState();
}

class _HelpCardState extends State<_HelpCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;

    return Semantics(
      button: true,
      expanded: _expanded,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expanded = !_expanded);
        },
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _expanded
                ? (isRetro ? AppColors.inputBackground : AppColors.cardHoverActive)
                : AppColors.cardBackground,
            borderRadius: isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(14),
            border: Border.all(
              color: isRetro
                  ? AppColors.cardBorder
                  : (_expanded
                      ? AppColors.accentPrimary.withValues(alpha: 0.3)
                      : AppColors.cardBorder),
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
              // ── Header row ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: _expanded
                          ? AppColors.accentPrimary
                          : (isRetro
                              ? AppColors.textPrimary
                              : AppColors.textPlaceholder),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: isRetro
                            ? RetroTypography.cardTitle.copyWith(
                                color: _expanded
                                    ? AppColors.accentPrimary
                                    : AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              )
                            : AppTypography.cardTitle.copyWith(
                                color: _expanded
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _expanded
                            ? AppColors.accentPrimary
                            : (isRetro
                                ? AppColors.textPrimary
                                : AppColors.textPlaceholder),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expandable body ─────────────────────────────────────────────
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(
                              height: 1,
                              color: isRetro
                                  ? AppColors.cardBorder
                                  : AppColors.subtleBorder,
                              thickness: isRetro ? 1.5 : 1.0,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.body,
                              style: isRetro
                                  ? RetroTypography.bodyText.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      height: 1.5,
                                    )
                                  : AppTypography.bodyText.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.55,
                                    ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
