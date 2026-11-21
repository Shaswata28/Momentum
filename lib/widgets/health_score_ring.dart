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
    final safeScore = score.isFinite ? score.clamp(0.0, 100.0) : 0.0;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Semantics(
      label:
          'Health score ${safeScore.toStringAsFixed(1)} out of 100, grade $grade',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reducedMotion ? safeScore : 0.0, end: safeScore),
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animatedScore, _) {
          return SizedBox(
            width: 160 * scale,
            height: 160 * scale,
            child: CustomPaint(
              painter: _RingPainter(
                score: animatedScore,
                isRetro: AppColors.isRetro,
                trackColor: AppColors.elevatedSurface,
                activeColor: _RingPainter._ringColor(animatedScore),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      grade == '-' || grade == '—' || (safeScore == 0 && grade == 'N/A')
                          ? '—'
                          : animatedScore.toStringAsFixed(1),
                      style: AppTypography.scoreStat.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grade,
                      style: AppTypography.displayHeading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _gradeColor(grade),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _gradeColor(String grade) {
    switch (grade) {
      case 'A':
        return AppColors.successDone;
      case 'B':
        return AppColors.accentPrimary;
      case 'C':
        return AppColors.accentPrimary;
      case 'D':
        return AppColors.warningTag;
      case '-':
      case '—':
      case 'N/A':
        return AppColors.textPlaceholder;
      default:
        return AppColors.errorAlert;
    }
  }
}

class _RingPainter extends CustomPainter {
  final double score;
  final bool isRetro;
  final Color trackColor;
  final Color activeColor;
  _RingPainter({
    required this.score,
    required this.isRetro,
    required this.trackColor,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;
    const strokeWidth = 12.0;
    const startAngle = -pi / 2;

    if (isRetro) {
      const totalBlocks = 20;
      const anglePerBlock = (2 * pi) / totalBlocks;
      const blockSpan = anglePerBlock * 0.72; // discrete pixel block gap
      final activeBlocks = ((score / 100) * totalBlocks).round();

      for (int i = 0; i < totalBlocks; i++) {
        final a = startAngle + i * anglePerBlock;
        final isFilled = i < activeBlocks;
        final paint = Paint()
          ..color = isFilled ? activeColor : trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14.0
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          a,
          blockSpan,
          false,
          paint,
        );
      }
      return;
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi,
      false,
      Paint()
        ..color = trackColor
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
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  static Color _ringColor(double score) {
    if (score <= 0) return AppColors.elevatedSurface;
    if (score >= 90) return AppColors.successDone;
    if (score >= 70) return AppColors.accentPrimary;
    if (score >= 60) return AppColors.warningTag;
    return AppColors.errorAlert;
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.score != score ||
      old.isRetro != isRetro ||
      old.trackColor != trackColor ||
      old.activeColor != activeColor;
}
