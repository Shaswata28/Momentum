import 'package:flutter/material.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Help & Guide', style: AppTypography.displayHeading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: const [
          // Intro
          _Intro(),
          SizedBox(height: 28),

          // ── Routine & Tasks ───────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.repeat_rounded,
            label: 'ROUTINE & TASKS',
            color: Color(0xFF1A6FE8),
          ),
          SizedBox(height: 10),
          _HelpCard(
            icon: Icons.construction_outlined,
            title: 'Building your daily routine',
            body:
                'Head over to Profile > Edit Routine to build your perfect day! You can schedule tasks for the Morning, Afternoon, or Evening.\n\n'
                'Don\'t forget to pick which days they happen—once you set it up, Momentum automatically generates your daily task list for you every single day.',
          ),
          _HelpCard(
            icon: Icons.add_circle_outline,
            title: 'Adding a quick temporary task',
            body:
                'Need to remember something just for today? Tap the "Add a task for today..." bar at the bottom of your Today screen.\n\n'
                'It\'s perfect for one-off things like "Call mom" or "Pick up a package" that don\'t belong in your permanent daily routine.',
          ),

          SizedBox(height: 28),

          // ── Wallet ────────────────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.account_balance_wallet_outlined,
            label: 'WALLET & FINANCE',
            color: Color(0xFF1D9E75),
          ),
          SizedBox(height: 10),
          _HelpCard(
            icon: Icons.tune_rounded,
            title: 'Setting up your Wallet',
            body:
                'To get the most out of your Wallet, tap the ⚙️ gear icon at the top of the Wallet screen! '
                'That\'s where you can set your starting balance, give yourself a Monthly Budget Limit (which powers the budget bar), '
                'and set a Savings Goal so you can watch your savings progress fill up.',
          ),
          _HelpCard(
            icon: Icons.receipt_long_outlined,
            title: 'Handling fixed bills',
            body:
                'Got rent, internet, or a monthly Spotify sub? Add it to the Fixed Bills section.\n\n'
                'Every month, a handy "Pay" button will appear next to each bill. Just tap it when you pay it, and Momentum will automatically log the expense and check it off your list for the month!',
          ),

          SizedBox(height: 28),

          // ── Insights ──────────────────────────────────────────────────────
          _GroupHeader(
            icon: Icons.insights_rounded,
            label: 'INSIGHTS & LOGS',
            color: Color(0xFF9B6FE8),
          ),
          SizedBox(height: 10),
          _HelpCard(
            icon: Icons.nightlight_outlined,
            title: 'What does EOD mean?',
            body:
                'EOD stands for "End of Day". You can set your EOD Reminder Time in your profile settings.\n\n'
                'When it goes off, you\'ll get a quick popup asking you to rate your mood, energy, and focus for the day. It\'s a tiny daily journal entry that takes 5 seconds to fill out.',
          ),
          _HelpCard(
            icon: Icons.grid_on_outlined,
            title: 'The purpose of Insights',
            body:
                'Insights is your personal growth dashboard! It takes your daily task scores and EOD reflections and turns them into a beautiful calendar heatmap.\n\n'
                'It\'s the best place to see your consistency streaks and spot patterns in your mood, productivity, and spending over time. The darker the square, the better your day was!',
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
        color: AppColors.accentPrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.accentPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap any item below to expand it and read a full explanation of how that feature works.',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
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
            letterSpacing: 1.2,
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
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _expanded
              ? const Color(0xFF141420)
              : const Color(0xFF121217),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expanded
                ? AppColors.accentPrimary.withValues(alpha: 0.25)
                : const Color(0xFF1A1A24),
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
                    color: _expanded
                        ? AppColors.accentPrimary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.bodyText.copyWith(
                        color: _expanded
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _expanded
                          ? AppColors.accentPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // ── Expandable body ─────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 1, color: const Color(0xFF1A1A24)),
                          const SizedBox(height: 12),
                          Text(
                            widget.body,
                            style: AppTypography.bodyText.copyWith(
                              color: const Color(0xFFAAAAAC),
                              fontSize: 13,
                              height: 1.65,
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
