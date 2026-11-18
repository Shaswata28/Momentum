import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../providers/wallet_providers.dart';

class BudgetBar extends StatelessWidget {
  final double spent;
  final double limit;

  const BudgetBar({super.key, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    if (limit <= 0) return const SizedBox.shrink();

    final pct = (spent / limit).clamp(0.0, 1.0);
    final over = spent > limit;
    final nearLimit = pct > 0.8 && !over;

    final Color barColor = over
        ? AppColors.errorAlert
        : (nearLimit ? AppColors.warningTag : AppColors.accentPrimary);

    final isRetro = AppColors.isRetro;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(18),
        border: Border.all(
          color: over
              ? AppColors.errorAlert
              : (isRetro
                    ? AppColors.cardBorder
                    : Colors.white.withValues(alpha: 0.07)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: isRetro ? BoxShape.rectangle : BoxShape.circle,
                      color: barColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('MONTHLY BUDGET', style: AppTypography.sectionLabel),
                ],
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: (spent / limit * 100)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) {
                  return Text(
                    '${val.toInt()}% spent',
                    style: AppTypography.tagChip.copyWith(
                      color: barColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) {
              if (isRetro) {
                const segmentCount = 12;
                final filledSegments = (val * segmentCount).round();
                return Row(
                  children: List.generate(segmentCount, (i) {
                    final isFilled = i < filledSegments;
                    return Expanded(
                      child: Container(
                        height: 10,
                        margin: EdgeInsets.only(
                          right: i < segmentCount - 1 ? 3 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isFilled
                              ? barColor
                              : AppColors.cardHoverActive,
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: val,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 7,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currencyFormat.format(spent),
                style: AppTypography.scoreStat.copyWith(
                  color: over ? AppColors.errorAlert : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Limit: ${currencyFormat.format(limit)}',
                textAlign: TextAlign.end,
                style: AppTypography.bodyText.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              if (over)
                Text(
                  'Over budget by ${currencyFormat.format(spent - limit)}',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.errorAlert,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
