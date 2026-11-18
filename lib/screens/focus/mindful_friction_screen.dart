import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/focus_blocker_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_colors.dart';
import '../../theme/retro_typography.dart';

class MindfulFrictionScreen extends StatefulWidget {
  final String packageName;
  final String appName;
  final String taskName;
  final DateTime? taskEndTime;

  const MindfulFrictionScreen({
    super.key,
    required this.packageName,
    required this.appName,
    required this.taskName,
    this.taskEndTime,
  });

  @override
  State<MindfulFrictionScreen> createState() => _MindfulFrictionScreenState();
}

class _MindfulFrictionScreenState extends State<MindfulFrictionScreen> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isUsingPass = false;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (widget.taskEndTime != null) {
      final diff = widget.taskEndTime!.difference(DateTime.now()).inSeconds;
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
      });
    }
  }

  String _formatRemaining() {
    if (widget.taskEndTime == null || _remainingSeconds <= 0) {
      return '--:--';
    }
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final m = mins % 60;
      return '${hrs}h ${m.toString().padLeft(2, '0')}m';
    }
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleUsePass() async {
    final passesLeft = FocusBlockerService().getRemainingEmergencyPasses();
    if (passesLeft <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No emergency passes left today.',
            style: AppColors.isRetro
                ? RetroTypography.bodyText.copyWith(color: AppColors.textPrimary)
                : null,
          ),
          backgroundColor: AppColors.cardBackground,
          behavior: SnackBarBehavior.floating,
          shape: AppColors.isRetro
              ? const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(color: RetroDarkColors.cardBorder, width: 2.0),
                )
              : null,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isUsingPass = true);
    final success = await FocusBlockerService().useEmergencyPass(
      targetPackage: widget.packageName,
      minutes: 5,
    );

    if (mounted) {
      setState(() => _isUsingPass = false);
      if (success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final passesRemaining = FocusBlockerService().getRemainingEmergencyPasses();
    final isRetro = AppColors.isRetro;
    final isDark = AppColors.isDark;

    // Brand colours
    final accent = AppColors.accentPrimary;
    final bg = AppColors.appBackground;
    final cardBg = AppColors.cardBackground;
    final border = AppColors.cardBorder;
    final shadow = AppColors.retroShadowColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Status badge ───────────────────────────────────────────────
              _StatusBadge(isRetro: isRetro, isDark: isDark),

              const Spacer(),

              // ── Shield icon ────────────────────────────────────────────────
              _ShieldIcon(accent: accent, border: border, shadow: shadow, isRetro: isRetro, isDark: isDark),

              const SizedBox(height: 20),

              // ── Blocked app name ───────────────────────────────────────────
              Text(
                widget.appName.toUpperCase(),
                style: isRetro
                    ? RetroTypography.overline.copyWith(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.textSecondary,
                      )
                    : AppTypography.sectionLabel.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary,
                      ),
              ),

              const SizedBox(height: 6),

              // ── Task name ──────────────────────────────────────────────────
              Text(
                widget.taskName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: isRetro
                    ? RetroTypography.displayHeading.copyWith(fontSize: 15, height: 1.4)
                    : AppTypography.displayHeading.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 20),

              // ── Countdown card ─────────────────────────────────────────────
              _CountdownCard(
                time: _formatRemaining(),
                isRetro: isRetro,
                isDark: isDark,
                cardBg: cardBg,
                border: border,
                shadow: shadow,
                accent: accent,
              ),

              const Spacer(),

              // ── PRIMARY: Stay Focused ──────────────────────────────────────
              _PrimaryButton(
                label: isRetro ? 'STAY FOCUSED' : 'Stay Focused',
                accent: accent,
                isRetro: isRetro,
                isDark: isDark,
                border: border,
                shadow: shadow,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 12),

              // ── SECONDARY: Emergency Pass ──────────────────────────────────
              _EmergencyPassButton(
                passesRemaining: passesRemaining,
                isLoading: _isUsingPass,
                isRetro: isRetro,
                isDark: isDark,
                cardBg: cardBg,
                border: border,
                shadow: shadow,
                onTap: _isUsingPass ? null : _handleUsePass,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isRetro;
  final bool isDark;
  const _StatusBadge({required this.isRetro, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isRetro ? AppColors.cardBackground : AppColors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(20),
        border: Border.all(
          color: isRetro ? AppColors.cardBorder : AppColors.accentPrimary.withValues(alpha: 0.25),
          width: isRetro ? 2.0 : 1.0,
        ),
        boxShadow: isRetro
            ? [BoxShadow(color: AppColors.retroShadowColor, offset: const Offset(2, 2), blurRadius: 0)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 13, color: AppColors.accentPrimary),
          const SizedBox(width: 6),
          Text(
            isRetro ? 'FOCUS SHIELD ACTIVE' : 'Focus Shield Active',
            style: isRetro
                ? RetroTypography.overline.copyWith(fontSize: 8, color: AppColors.textPrimary)
                : AppTypography.tagChip.copyWith(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShieldIcon extends StatelessWidget {
  final Color accent;
  final Color border;
  final Color shadow;
  final bool isRetro;
  final bool isDark;
  const _ShieldIcon({
    required this.accent,
    required this.border,
    required this.shadow,
    required this.isRetro,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isRetro ? accent : accent.withValues(alpha: 0.1),
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(26),
        border: Border.all(color: isRetro ? border : accent.withValues(alpha: 0.35), width: isRetro ? 2.0 : 1.5),
        boxShadow: isRetro
            ? [BoxShadow(color: shadow, offset: const Offset(5, 5), blurRadius: 0)]
            : [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: Icon(
        Icons.shield_rounded,
        size: 44,
        color: isRetro ? (isDark ? const Color(0xFF141418) : Colors.white) : accent,
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final String time;
  final bool isRetro;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color shadow;
  final Color accent;

  const _CountdownCard({
    required this.time,
    required this.isRetro,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.shadow,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(18),
        border: Border.all(color: border, width: isRetro ? 2.0 : 1.0),
        boxShadow: isRetro
            ? [BoxShadow(color: shadow, offset: const Offset(4, 4), blurRadius: 0)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_bottom_rounded, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                isRetro ? 'TIME REMAINING' : 'Time remaining',
                style: isRetro
                    ? RetroTypography.overline.copyWith(fontSize: 8, color: AppColors.textSecondary)
                    : AppTypography.tagChip.copyWith(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            time,
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 30, letterSpacing: 2, color: AppColors.textPrimary)
                : AppTypography.amountLarge.copyWith(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay in flow. You\'re making real progress.',
            textAlign: TextAlign.center,
            style: isRetro
                ? RetroTypography.bodyText.copyWith(fontSize: 9, color: AppColors.textMuted)
                : AppTypography.bodyText.copyWith(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color accent;
  final Color border;
  final Color shadow;
  final bool isRetro;
  final bool isDark;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.accent,
    required this.border,
    required this.shadow,
    required this.isRetro,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(14),
          border: Border.all(color: isRetro ? border : Colors.transparent, width: isRetro ? 2.0 : 0),
          boxShadow: isRetro
              ? [BoxShadow(color: shadow, offset: const Offset(4, 4), blurRadius: 0)]
              : [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18,
                color: isRetro && !isDark ? AppColors.textPrimary : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: isRetro
                  ? RetroTypography.buttonLabel.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF141418) : AppColors.textPrimary,
                    )
                  : AppTypography.buttonLabel.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyPassButton extends StatelessWidget {
  final int passesRemaining;
  final bool isLoading;
  final bool isRetro;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color shadow;
  final VoidCallback? onTap;

  const _EmergencyPassButton({
    required this.passesRemaining,
    required this.isLoading,
    required this.isRetro,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.shadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPass = passesRemaining > 0;
    final labelColor = hasPass ? AppColors.textPrimary : AppColors.textPlaceholder;
    final iconColor = hasPass ? AppColors.warningTag : AppColors.textPlaceholder;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isRetro
              ? (hasPass ? AppColors.inputBackground : cardBg)
              : cardBg,
          borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(14),
          border: Border.all(
            color: isRetro
                ? border
                : (hasPass
                    ? AppColors.warningTag.withValues(alpha: 0.4)
                    : AppColors.subtleBorder),
            width: isRetro ? 2.0 : 1.0,
          ),
          boxShadow: isRetro && hasPass
              ? [BoxShadow(color: shadow, offset: const Offset(3, 3), blurRadius: 0)]
              : null,
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warningTag),
                ),
              )
            : Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasPass
                          ? (isRetro ? 'EMERGENCY PASS  (5 MIN)' : 'Use Emergency Pass  · 5 min')
                          : (isRetro ? 'NO PASSES LEFT TODAY' : 'No Emergency Passes Left'),
                      style: isRetro
                          ? RetroTypography.buttonLabel.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            )
                          : AppTypography.buttonLabel.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                    ),
                  ),
                  // Badge showing passes left
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRetro
                          ? (hasPass
                              ? (isDark ? const Color(0xFF332616) : const Color(0xFFD9CCAA))
                              : (isDark ? const Color(0xFF262630) : const Color(0xFFCFC8B2)))
                          : (hasPass
                              ? AppColors.warningTag.withValues(alpha: 0.12)
                              : AppColors.textPlaceholder.withValues(alpha: 0.1)),
                      borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(6),
                      border: isRetro ? Border.all(color: border, width: 1.0) : null,
                    ),
                    child: Text(
                      '$passesRemaining LEFT',
                      style: isRetro
                          ? RetroTypography.overline.copyWith(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              color: hasPass
                                  ? (isDark ? AppColors.warningTag : const Color(0xFFB45309))
                                  : AppColors.textPlaceholder,
                            )
                          : AppTypography.tagChip.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: hasPass ? AppColors.warningTag : AppColors.textPlaceholder,
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
