import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/focus_blocker_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

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

class _MindfulFrictionScreenState extends State<MindfulFrictionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isUsingPass = false;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breatheAnimation = CurvedAnimation(
      parent: _breatheController,
      curve: Curves.easeInOutSine,
    );

    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateRemainingTime();
      }
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
      return 'Session in progress';
    }
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final m = mins % 60;
      return '${hrs}h ${m}m left';
    }
    return '$mins:${secs.toString().padLeft(2, '0')} left';
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleUsePass() async {
    final passesLeft = FocusBlockerService().getRemainingEmergencyPasses();
    if (passesLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No emergency passes left today.'),
          backgroundColor: AppColors.cardHoverActive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUsingPass = true);
    final success = await FocusBlockerService().useEmergencyPass(
      targetPackage: widget.packageName,
      minutes: 5,
    );

    if (mounted) {
      setState(() => _isUsingPass = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passesRemaining = FocusBlockerService().getRemainingEmergencyPasses();

    return Scaffold(
      backgroundColor: AppColors.appBackground.withValues(alpha: 0.94),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Name
                  Text(
                    widget.appName,
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Minimal Breathing Circle
                  AnimatedBuilder(
                    animation: _breatheAnimation,
                    builder: (context, child) {
                      final scale = 1.0 + (_breatheAnimation.value * 0.2);
                      final isBreathingIn = _breatheController.status == AnimationStatus.forward;
                      return Column(
                        children: [
                          Container(
                            width: 100 * scale,
                            height: 100 * scale,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentPrimary.withValues(alpha: 0.12),
                              border: Border.all(
                                color: AppColors.accentPrimary.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              size: 32,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isBreathingIn ? 'Breathe in...' : 'Breathe out...',
                            style: AppTypography.cardTime.copyWith(
                              fontSize: 12,
                              color: AppColors.accentPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Active Task Title
                  Text(
                    widget.taskName,
                    textAlign: TextAlign.center,
                    style: AppTypography.displayHeading.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Remaining Time
                  Text(
                    _formatRemaining(),
                    style: AppTypography.cardTime.copyWith(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Primary Action: Stay Focused
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Stay Focused',
                        style: AppTypography.buttonLabel.copyWith(fontSize: 14.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Secondary Action: Emergency Pass
                  GestureDetector(
                    onTap: _isUsingPass ? null : _handleUsePass,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Emergency pass (5m)',
                            style: AppTypography.bodyText.copyWith(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            ' · ',
                            style: AppTypography.bodyText.copyWith(
                              fontSize: 12.5,
                              color: AppColors.textPlaceholder,
                            ),
                          ),
                          Text(
                            '$passesRemaining left',
                            style: AppTypography.cardTime.copyWith(
                              fontSize: 12.5,
                              color: passesRemaining > 0 ? AppColors.warningTag : AppColors.textPlaceholder,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
