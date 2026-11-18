import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../models/saving_goal.dart';
import '../../../providers/wallet_providers.dart';
import '../../../widgets/action_button.dart';

PhosphorIconData _resolveGoalIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('phone') ||
      lower.contains('mobile') ||
      lower.contains('iphone') ||
      lower.contains('pixel') ||
      lower.contains('samsung') ||
      lower.contains('ipad') ||
      lower.contains('tab') ||
      lower.contains('tech') ||
      lower.contains('gadget') ||
      lower.contains('mac') ||
      lower.contains('laptop') ||
      lower.contains('pc')) {
    return PhosphorIconsRegular.deviceMobile;
  }
  if (lower.contains('tour') ||
      lower.contains('travel') ||
      lower.contains('trip') ||
      lower.contains('flight') ||
      lower.contains('vacation') ||
      lower.contains('cox') ||
      lower.contains('sajek')) {
    return PhosphorIconsRegular.airplaneTilt;
  }
  if (lower.contains('house') ||
      lower.contains('home') ||
      lower.contains('furniture') ||
      lower.contains('flat') ||
      lower.contains('room')) {
    return PhosphorIconsRegular.house;
  }
  if (lower.contains('car') ||
      lower.contains('bike') ||
      lower.contains('motorcycle') ||
      lower.contains('scooter') ||
      lower.contains('vehicle')) {
    return PhosphorIconsRegular.bus;
  }
  if (lower.contains('book') ||
      lower.contains('course') ||
      lower.contains('study') ||
      lower.contains('education') ||
      lower.contains('exam')) {
    return PhosphorIconsRegular.bookOpen;
  }
  if (lower.contains('gift') ||
      lower.contains('present') ||
      lower.contains('eid') ||
      lower.contains('birthday')) {
    return PhosphorIconsRegular.gift;
  }
  if (lower.contains('shop') ||
      lower.contains('buy') ||
      lower.contains('cloth') ||
      lower.contains('shoe') ||
      lower.contains('dress')) {
    return PhosphorIconsRegular.shoppingBag;
  }
  if (lower.contains('save') ||
      lower.contains('emergency') ||
      lower.contains('fund') ||
      lower.contains('invest')) {
    return PhosphorIconsRegular.wallet;
  }
  return PhosphorIconsRegular.star;
}

class SavingsGoalSection extends ConsumerWidget {
  const SavingsGoalSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingGoalsProvider);
    final monthId = ref.watch(currentMonthIdProvider);
    final isRetro = AppColors.isRetro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'SAVING GOALS',
                style: AppTypography.sectionLabel,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showAddGoalSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(
                    alpha: isRetro ? 0.2 : 0.12,
                  ),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: isRetro ? 1.5 : 1.0,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      semanticLabel: 'Add saving goal',
                      color: AppColors.accentPrimary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: AppTypography.buttonLabel.copyWith(
                        color: AppColors.accentPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Empty state or Goals list
        if (goals.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: isRetro
                  ? BorderRadius.zero
                  : BorderRadius.circular(16),
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
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: AppColors.textPlaceholder,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  'No saving goals yet',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: goals.asMap().entries.map((entry) {
              final isLast = entry.key == goals.length - 1;
              return _GoalCard(
                goal: entry.value,
                monthId: monthId,
                isLast: isLast,
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: AppColors.isRetro
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      builder: (_) => const _AddGoalSheet(),
    );
  }
}

// ── Goal Card Widget ──────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  final SavingGoal goal;
  final String monthId;
  final bool isLast;

  const _GoalCard({
    required this.goal,
    required this.monthId,
    required this.isLast,
  });

  String _formatAmount(double amount) {
    return '৳${NumberFormat('#,##0').format(amount)}';
  }

  String _formatEstimatedTime(int? months) {
    if (months == null) return 'No rate set';
    if (months == 0) return 'Goal reached!';
    if (months == 1) return '~1 month to go';
    if (months < 12) return '~$months months to go';
    final yrs = months ~/ 12;
    final rem = months % 12;
    return rem == 0 ? '~$yrs yr to go' : '~$yrs yr $rem mo to go';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRetro = AppColors.isRetro;
    final isCompleted = goal.isCompleted;
    final thisMonthSaved = goal.deposits[monthId] ?? 0.0;
    final progressPct = (goal.progress * 100).toInt();

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppColors.successDone.withValues(alpha: 0.6)
              : AppColors.cardBorder,
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
      child: InkWell(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showDeleteDialog(context, ref);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title/Target + Deposit Button / Reached Badge
            Row(
              children: [
                // Icon Badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isCompleted
                            ? AppColors.successDone
                            : AppColors.accentPrimary)
                        .withValues(
                      alpha: isRetro ? 0.2 : 0.12,
                    ),
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(10),
                    border: isRetro
                        ? Border.all(color: AppColors.cardBorder, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    _resolveGoalIcon(goal.name),
                    color: isCompleted
                        ? AppColors.successDone
                        : AppColors.accentPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Monthly target subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Target: ${_formatAmount(goal.targetAmount)} · ${_formatAmount(goal.monthlyTarget)}/mo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action button or Completed badge
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successDone.withValues(
                        alpha: isRetro ? 0.2 : 0.12,
                      ),
                      borderRadius: isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.successDone.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.successDone,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reached!',
                          style: AppTypography.buttonLabel.copyWith(
                            color: AppColors.successDone,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (thisMonthSaved >= goal.monthlyTarget)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showDepositSheet(context, ref, isExtra: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successDone.withValues(
                          alpha: isRetro ? 0.2 : 0.12,
                        ),
                        borderRadius: isRetro
                            ? BorderRadius.zero
                            : BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.successDone.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.successDone,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Deposited',
                            style: AppTypography.buttonLabel.copyWith(
                              color: AppColors.successDone,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showDepositSheet(context, ref, isExtra: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(
                          alpha: isRetro ? 0.25 : 0.15,
                        ),
                        borderRadius: isRetro
                            ? BorderRadius.zero
                            : BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.cardBorder,
                          width: isRetro ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 12,
                            color: AppColors.accentPrimary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            thisMonthSaved > 0 ? 'Add More' : 'Deposit',
                            style: AppTypography.buttonLabel.copyWith(
                              color: AppColors.accentPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar & Percentage
            Row(
              children: [
                Expanded(
                  child: isRetro
                      ? _buildRetroProgressBar(goal.progress, isCompleted)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: goal.progress,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? AppColors.successDone
                                  : AppColors.accentPrimary,
                            ),
                            minHeight: 7,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$progressPct%',
                  style: AppTypography.tagChip.copyWith(
                    color: isCompleted
                        ? AppColors.successDone
                        : AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom Info: Saved vs Target & Estimated Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Saved / Left
                Text(
                  isCompleted
                      ? '${_formatAmount(goal.savedSoFar)} saved'
                      : '${_formatAmount(goal.savedSoFar)} saved (${_formatAmount(goal.remainingAmount)} left)',
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.5,
                  ),
                ),

                // Estimated time to goal
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.celebration_rounded
                          : Icons.schedule_rounded,
                      size: 12,
                      color: isCompleted
                          ? AppColors.successDone
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatEstimatedTime(goal.estimatedMonthsRemaining),
                      style: AppTypography.bodyText.copyWith(
                        color: isCompleted
                            ? AppColors.successDone
                            : AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight:
                            isCompleted ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Current Month Deposit Status (if any)
            if (thisMonthSaved > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 11,
                    color: AppColors.successDone,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Saved ${_formatAmount(thisMonthSaved)} this month',
                    style: AppTypography.bodyText.copyWith(
                      color: AppColors.successDone,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRetroProgressBar(double progress, bool isCompleted) {
    const segmentCount = 14;
    final filledSegments = (progress * segmentCount).round();
    return Row(
      children: List.generate(segmentCount, (i) {
        final isFilled = i < filledSegments;
        return Expanded(
          child: Container(
            height: 9,
            margin: EdgeInsets.only(right: i < segmentCount - 1 ? 2 : 0),
            decoration: BoxDecoration(
              color: isFilled
                  ? (isCompleted
                      ? AppColors.successDone
                      : AppColors.accentPrimary)
                  : AppColors.cardHoverActive,
              border: Border.all(
                color: AppColors.cardBorder,
                width: 1.2,
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showDepositSheet(
    BuildContext context,
    WidgetRef ref, {
    bool isExtra = false,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: AppColors.isRetro
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      builder: (_) => _DepositSheet(
        goal: goal,
        monthId: monthId,
        isExtra: isExtra,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: AppColors.isRetro
            ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Goal?',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Delete "${goal.name}"? Recorded savings of ${_formatAmount(goal.savedSoFar)} will be removed.',
          style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(walletNotifierProvider.notifier)
                  .deleteSavingGoal(goal.id);
            },
            child: Text(
              'Delete',
              style: AppTypography.buttonLabel.copyWith(
                color: AppColors.errorAlert,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Goal Bottom Sheet ─────────────────────────────────────────────────────

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _monthlyTargetController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _monthlyTargetController.dispose();
    super.dispose();
  }

  int? get _estimatedMonths {
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final monthly = double.tryParse(_monthlyTargetController.text.trim()) ?? 0;
    if (price <= 0 || monthly <= 0) return null;
    return (price / monthly).ceil();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final monthly =
        double.tryParse(_monthlyTargetController.text.trim()) ?? 0.0;

    if (name.isEmpty || price <= 0 || monthly <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields with valid values.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newGoal = SavingGoal(
        id: const Uuid().v4(),
        name: name,
        targetAmount: price,
        monthlyTarget: monthly,
        createdAt: DateTime.now(),
      );

      await ref.read(walletNotifierProvider.notifier).addSavingGoal(newGoal);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal "$name" created!'),
            backgroundColor: AppColors.successDone,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create goal. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final estMonths = _estimatedMonths;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: isRetro
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(20)),
          border: isRetro
              ? Border.all(color: AppColors.cardBorder, width: 2.0)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            if (!isRetro)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Sheet Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEW SAVING GOAL',
                  style: AppTypography.sectionLabel,
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Field 1: Name
            Text(
              'What do you want to buy?',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: _inputDecoration('e.g. MacBook Pro, Bike, New Phone'),
            ),
            const SizedBox(height: 14),

            // Field 2: Target Price (৳)
            Text(
              'Target Price (৳)',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: _inputDecoration('e.g. 120000'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            // Field 3: Monthly Target (৳)
            Text(
              'Monthly Saving Target (৳)',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _monthlyTargetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: _inputDecoration('e.g. 10000'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),

            // Live ETA Preview Banner
            if (estMonths != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(
                    alpha: isRetro ? 0.2 : 0.1,
                  ),
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.cardBorder,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estimated time: ~$estMonths months to reach goal',
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 6),

            // Submit Button
            ActionButton(
              label: 'Create Goal',
              isPrimary: true,
              isLoading: _isSaving,
              onTap: _isSaving ? null : _handleSave,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final isRetro = AppColors.isRetro;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyText.copyWith(
        color: AppColors.textPlaceholder,
      ),
      filled: true,
      fillColor: AppColors.cardHoverActive,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.cardBorder,
          width: isRetro ? 1.5 : 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.cardBorder,
          width: isRetro ? 1.5 : 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.accentPrimary,
          width: isRetro ? 2.0 : 1.5,
        ),
      ),
    );
  }
}

// ── Deposit Bottom Sheet ──────────────────────────────────────────────────────

class _DepositSheet extends ConsumerStatefulWidget {
  final SavingGoal goal;
  final String monthId;
  final bool isExtra;

  const _DepositSheet({
    required this.goal,
    required this.monthId,
    this.isExtra = false,
  });

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _amountController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final thisMonthSaved = widget.goal.deposits[widget.monthId] ?? 0.0;
    final monthlyNeeded = (widget.goal.monthlyTarget - thisMonthSaved)
        .clamp(0.0, widget.goal.remainingAmount);

    final double defaultAmt;
    if (widget.isExtra || monthlyNeeded <= 0) {
      defaultAmt = widget.goal.remainingAmount < widget.goal.monthlyTarget
          ? widget.goal.remainingAmount
          : widget.goal.monthlyTarget;
    } else {
      defaultAmt = monthlyNeeded;
    }

    if (defaultAmt > 0) {
      _amountController.text = defaultAmt % 1 == 0
          ? defaultAmt.toInt().toString()
          : defaultAmt.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleDeposit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(walletNotifierProvider.notifier).addSavingGoalDeposit(
            goalId: widget.goal.id,
            monthKey: widget.monthId,
            amount: amount,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ৳${NumberFormat('#,##0').format(amount)} to "${widget.goal.name}"',
            ),
            backgroundColor: AppColors.successDone,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record deposit. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final remaining = widget.goal.remainingAmount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: isRetro
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(20)),
          border: isRetro
              ? Border.all(color: AppColors.cardBorder, width: 2.0)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            if (!isRetro)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.isExtra
                        ? 'ADD EXTRA SAVINGS: ${widget.goal.name.toUpperCase()}'
                        : 'RECORD SAVINGS: ${widget.goal.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionLabel,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status chip: Target & Remaining
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardHoverActive,
                borderRadius: isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.cardBorder,
                  width: isRetro ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Target',
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '৳${NumberFormat('#,##0').format(widget.goal.targetAmount)}',
                        style: AppTypography.scoreStat.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Still Needed',
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '৳${NumberFormat('#,##0').format(remaining)}',
                        style: AppTypography.scoreStat.copyWith(
                          color: AppColors.accentPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Amount field
            Text(
              'Amount Saved (${widget.monthId})',
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter amount (৳)',
                hintStyle: AppTypography.bodyText.copyWith(
                  color: AppColors.textPlaceholder,
                ),
                prefixText: '৳ ',
                prefixStyle: AppTypography.bodyText.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: AppColors.cardHoverActive,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.cardBorder,
                    width: isRetro ? 1.5 : 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.cardBorder,
                    width: isRetro ? 1.5 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: AppColors.accentPrimary,
                    width: isRetro ? 2.0 : 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildQuickChip(
                  'Monthly Target (৳${NumberFormat('#,##0').format(widget.goal.monthlyTarget)})',
                  widget.goal.monthlyTarget,
                ),
                if (remaining > 0 && remaining != widget.goal.monthlyTarget)
                  _buildQuickChip(
                    'Full Remaining (৳${NumberFormat('#,##0').format(remaining)})',
                    remaining,
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Submit
            ActionButton(
              label: widget.isExtra ? 'Deposit Extra' : 'Confirm Deposit',
              isPrimary: true,
              isLoading: _isSaving,
              onTap: _isSaving ? null : _handleDeposit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, double amount) {
    final isRetro = AppColors.isRetro;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _amountController.text = amount % 1 == 0
            ? amount.toInt().toString()
            : amount.toStringAsFixed(2);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardHoverActive,
          borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.tagChip.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
