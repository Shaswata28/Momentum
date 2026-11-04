import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Help & Guide Screen
// ─────────────────────────────────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Help & Guide',
          style: AppTypography.displayHeading.copyWith(fontSize: 22),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        children: [
          // Intro
          const _Intro(),
          const SizedBox(height: 28),

          // ── Routine & Tasks ───────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.repeat_rounded,
            label: 'ROUTINE & TASKS',
            color: AppColors.accentPrimary,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.construction_outlined,
            title: 'Building your daily routine',
            body:
                'Head over to Profile > Routine Builder to set up your weekly routine! You can schedule recurring tasks for specific days of the week.\n\n'
                'Momentum automatically generates your daily task list for you every morning based on what day it is.',
          ),
          const _HelpCard(
            icon: Icons.add_circle_outline,
            title: 'Adding a quick temporary task',
            body:
                'Need to remember something just for today? Tap the "Add a task for today..." bar on your Today screen.\n\n'
                'It\'s perfect for one-off tasks like "Call plumber" or "Pick up a parcel" that don\'t belong in your permanent weekly routine.',
          ),

          const SizedBox(height: 28),

          // ── Wallet ────────────────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.account_balance_wallet_outlined,
            label: 'WALLET & FINANCE',
            color: AppColors.successDone,
          ),
          const SizedBox(height: 12),
          const _HelpCard(
            icon: Icons.tune_rounded,
            title: 'Setting up your Wallet',
            body:
                'To configure your finances, tap the tune icon at the top of the Wallet screen. '
                'Set your starting cash balance, define a Monthly Budget Limit to track against, '
                'and set a Semester Savings Target to visualize your savings milestones.',
          ),
          const _HelpCard(
            icon: Icons.receipt_long_outlined,
            title: 'Handling fixed bills',
            body:
                'Got rent, subscriptions, or utility bills? Add them to the Fixed Bills section.\n\n'
                'Each month, a single-tap "Pay" button lets you record payment instantly, checking it off your list and updating your ledger.',
          ),

          const SizedBox(height: 28),

          // ── Focus & Shield ────────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.shield_outlined,
            label: 'FOCUS SHIELD',
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

          const SizedBox(height: 28),

          // ── Insights ──────────────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.insights_rounded,
            label: 'INSIGHTS & LOGS',
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
            title: 'Consistency heatmap & pacing',
            body:
                'Insights transforms your daily task completions and EOD logs into a 35-day consistency heatmap.\n\n'
                'The Wallet tab in Insights calculates your Safe Daily Spending limit so you never run out of budget before month end.',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap any topic below to expand it and read how the system helps you maintain momentum.',
              style: AppTypography.bodyText.copyWith(
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
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.sectionLabel.copyWith(
            color: color,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w700,
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _expanded ? AppColors.cardHoverActive : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? AppColors.accentPrimary.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: _expanded ? AppColors.accentPrimary : AppColors.textPlaceholder,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.cardTitle.copyWith(
                        color: _expanded ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _expanded ? AppColors.accentPrimary : AppColors.textPlaceholder,
                    ),
                  ),
                ],
              ),
            ),

            // ── Expandable body ─────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
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
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.body,
                            style: AppTypography.bodyText.copyWith(
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
    );
  }
}
