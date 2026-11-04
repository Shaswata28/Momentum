import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final isDndActive = todayTasks.any((t) => t.enableDND && t.status == TaskStatus.inProgress);
    final blockedCount = FocusBlockerService().getBlockedPackages().length;

    return Row(
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
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.adHocTask.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 14,
                        color: AppColors.adHocTask,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'WALLET',
                      style: AppTypography.sectionLabel.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                    const Spacer(),
                    // Sleek unified '+ Log' action pill
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const TransactionSheet(initialIsIncome: false),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.8,
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
                            const SizedBox(width: 2.5),
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

                // Center: Balance Value
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: balance),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return Text(
                      currencyFormat.format(val),
                      style: AppTypography.displayHeading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),

                // Bottom Row: Subtitle + Forward Chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available Balance',
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppBlockerSettingsScreen()),
              );
              if (mounted) setState(() {});
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Category Label + Active/Ready Status Pill
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 14,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'SHIELD',
                      style: AppTypography.sectionLabel.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDndActive
                            ? AppColors.successDone.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDndActive
                              ? AppColors.successDone.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isDndActive ? 'ACTIVE' : 'READY',
                        style: AppTypography.cardTime.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDndActive ? AppColors.successDone : AppColors.textPlaceholder,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                // Center: Large Shield Emblem with Number of Blocked Apps Inside
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 52,
                        color: isDndActive
                            ? AppColors.accentPrimary.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      Icon(
                        Icons.shield_outlined,
                        size: 52,
                        color: isDndActive
                            ? AppColors.accentPrimary
                            : Colors.white.withValues(alpha: 0.24),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3.5),
                        child: Text(
                          '$blockedCount',
                          style: AppTypography.scoreStat.copyWith(
                            fontSize: blockedCount > 99 ? 15 : 19,
                            fontWeight: FontWeight.w700,
                            color: isDndActive ? Colors.white : AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Row: Subtitle + Forward Chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        blockedCount == 1 ? '1 app blocked' : '$blockedCount apps shielded',
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

  Widget _buildSquareCard({required Widget child, required VoidCallback onTap}) {
    return Container(
      height: 138,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }
}
