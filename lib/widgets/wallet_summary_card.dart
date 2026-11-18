import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_providers.dart';
import '../providers/dashboard_providers.dart';
import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../services/focus_blocker_service.dart';
import '../screens/wallet/transaction_sheet.dart';
import '../screens/profile/app_blocker_settings_screen.dart';

class WalletSummaryCard extends ConsumerStatefulWidget {
  const WalletSummaryCard({super.key});

  @override
  ConsumerState<WalletSummaryCard> createState() => _WalletSummaryCardState();
}

class _WalletSummaryCardState extends ConsumerState<WalletSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(runningBalanceProvider);
    final todayTasks = ref.watch(todayTasksProvider);
    final isDndActive = todayTasks.any(
      (t) => t.enableDND && t.status == TaskStatus.inProgress,
    );
    final blockedCount = FocusBlockerService().getBlockedPackages().length;
    final isRetro = AppColors.isRetro;
    final now = DateTime.now();
    final monthYear = DateFormat('MMM yyyy').format(now);
    final currencyFormat = NumberFormat.currency(
      symbol: '৳',
      decimalDigits: 2,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Square Wallet Card (Left) ───────────────────────────
        Expanded(
          child: _buildSquareCard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                shape: isRetro
                    ? const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      )
                    : null,
                builder: (_) => const TransactionSheet(initialIsIncome: false),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Category Label + Sleek Unified '+ Log' Pill
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.adHocTask.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(isRetro ? 0 : 6),
                        border: isRetro
                            ? Border.all(
                                color: AppColors.cardBorder,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 13,
                        color: AppColors.adHocTask,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'WALLET',
                        style: AppTypography.sectionLabel.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          color: AppColors.textPlaceholder,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Sleek unified '+ Log' action pill
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          shape: isRetro
                              ? const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                )
                              : null,
                          builder: (_) =>
                              const TransactionSheet(initialIsIncome: false),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isRetro
                              ? AppColors.cardHoverActive
                              : Colors.white.withValues(
                                  alpha: AppColors.isDark ? 0.05 : 0.08,
                                ),
                          borderRadius: BorderRadius.circular(isRetro ? 0 : 6),
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: isRetro ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 11,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'LOG',
                              style: AppTypography.cardTime.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Center: Balance Value
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: balance),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyFormat.format(val),
                        style: (isRetro
                                ? AppTypography.amountMedium
                                : AppTypography.displayHeading)
                            .copyWith(
                              fontSize: isRetro ? 18 : 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: isRetro ? 0.5 : -0.4,
                            ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Bottom Row: Subtitle + Forward Chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cash balance · $monthYear',
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9.5,
                      color: AppColors.textPlaceholder,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // ── 2. Square Focus Shield Card (Right) ─────────────────────
        Expanded(
          child: _buildSquareCard(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppBlockerSettingsScreen(),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Category Label + Active/Ready Status Pill
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(
                          isRetro ? 0 : 6,
                        ),
                        border: isRetro
                            ? Border.all(
                                color: AppColors.cardBorder,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 13,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'SHIELD',
                        style: AppTypography.sectionLabel.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          color: AppColors.textPlaceholder,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDndActive
                            ? AppColors.successDone.withValues(alpha: 0.16)
                            : (isRetro
                                ? AppColors.cardHoverActive
                                : Colors.white.withValues(
                                    alpha: AppColors.isDark ? 0.05 : 0.08,
                                  )),
                        borderRadius: BorderRadius.circular(isRetro ? 0 : 6),
                        border: Border.all(
                          color: isDndActive
                              ? AppColors.successDone.withValues(alpha: 0.3)
                              : AppColors.cardBorder,
                          width: isRetro ? 1.5 : 0.8,
                        ),
                      ),
                      child: Text(
                        isDndActive ? 'ACTIVE' : 'READY',
                        style: AppTypography.cardTime.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDndActive
                              ? AppColors.successDone
                              : AppColors.textPlaceholder,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Center: Large Shield Emblem with Number of Blocked Apps Inside
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 46,
                        color: isDndActive
                            ? AppColors.accentPrimary.withValues(alpha: 0.22)
                            : (AppColors.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05)),
                      ),
                      Icon(
                        Icons.shield_outlined,
                        size: 46,
                        color: isDndActive
                            ? AppColors.accentPrimary
                            : (AppColors.isDark
                                ? Colors.white.withValues(alpha: 0.24)
                                : Colors.black.withValues(alpha: 0.18)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.5),
                        child: Text(
                          '$blockedCount',
                          style: AppTypography.scoreStat.copyWith(
                            fontSize: blockedCount > 99 ? 14 : 17,
                            fontWeight: FontWeight.w700,
                            color: isDndActive
                                ? (isRetro
                                    ? AppColors.accentPrimary
                                    : Colors.white)
                                : AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Bottom Row: Subtitle + Forward Chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        blockedCount == 1
                            ? '1 app blocked'
                            : '$blockedCount apps shielded',
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9.5,
                      color: AppColors.textPlaceholder,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSquareCard({
    required Widget child,
    required VoidCallback onTap,
  }) {
    final isRetro = AppColors.isRetro;
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
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
                  color: Colors.black.withValues(
                    alpha: AppColors.isDark ? 0.16 : 0.05,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.25,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
