import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class HealthScoreRing extends StatelessWidget {
  final double score;
  final String grade;

  const HealthScoreRing({super.key, required this.score, required this.grade});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: score),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedScore, _) {
        return SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: _RingPainter(score: animatedScore),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    animatedScore.toStringAsFixed(1),
                    style: AppTypography.displayHeading.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    grade,
                    style: AppTypography.scoreStat.copyWith(
                      fontSize: 16,
                      color: _gradeColor(grade),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _gradeColor(String grade) {
    switch (grade) {
      case 'A': return AppColors.successDone;
      case 'B': return AppColors.accentPrimary;
      case 'C': return AppColors.accentPrimary;
      case 'D': return AppColors.warningTag;
      default:  return AppColors.errorAlert;
    }
  }
}

class _RingPainter extends CustomPainter {
  final double score;
  _RingPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;
    const strokeWidth = 12.0;
    const startAngle = -pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi,
      false,
      Paint()
        ..color = AppColors.elevatedSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (score > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        (score / 100) * 2 * pi,
        false,
        Paint()
          ..color = _ringColor(score)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  static Color _ringColor(double score) {
    if (score >= 90) return AppColors.successDone;
    if (score >= 70) return AppColors.accentPrimary;
    if (score >= 60) return AppColors.warningTag;
    return AppColors.errorAlert;
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.score != score;
}
