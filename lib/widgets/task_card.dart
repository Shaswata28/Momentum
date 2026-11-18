import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'tag_chip.dart';
import 'action_button.dart';

class TaskCard extends StatefulWidget {
  final DailyTaskInstance task;
  final FutureOr<void> Function() onMarkDone;
  final FutureOr<void> Function()? onStart;
  final FutureOr<void> Function() onSkip;
  final FutureOr<void> Function(DateTime date) onReschedule;
  final FutureOr<void> Function()? onDismissBuffer;

  const TaskCard({
    super.key,
    required this.task,
    required this.onMarkDone,
    this.onStart,
    required this.onSkip,
    required this.onReschedule,
    this.onDismissBuffer,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isExpanded = false;
  final bool _justCompleted = false;
  bool _busy = false;

  Future<void> _mutate(FutureOr<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _isExpanded = false);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish the action. Check the task and try again.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleExpand() {
    if (widget.task.status == TaskStatus.done || widget.task.isBufferBlock)
      return;
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
  }

  void _handleCheckboxTap() {
    if (widget.task.status == TaskStatus.done || widget.task.isBufferBlock)
      return;
    HapticFeedback.mediumImpact();
    _mutate(widget.onMarkDone);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String? _getTimeString() {
    if (widget.task.isBufferBlock) return null;
    if (widget.task.taskType == TaskType.fixed ||
        widget.task.taskType == TaskType.adhoc) {
      return _formatTime(widget.task.scheduledTime);
    } else {
      return widget.task.flexWindowEnd != null
          ? '~${_formatTime(widget.task.flexWindowEnd)}'
          : 'Flexible';
    }
  }

  bool _canStart() {
    if (widget.task.status == TaskStatus.missed) return true;
    if (widget.task.status != TaskStatus.pending) return false;
    final now = DateTime.now();

    if (widget.task.taskType == TaskType.fixed ||
        widget.task.taskType == TaskType.adhoc) {
      if (widget.task.scheduledTime == null) return true;
      final t = DateTime(
        now.year,
        now.month,
        now.day,
        widget.task.scheduledTime!.hour,
        widget.task.scheduledTime!.minute,
      );
      return now.isAfter(t.subtract(const Duration(minutes: 5)));
    } else {
      if (widget.task.flexWindowStart == null) return true;
      final t = DateTime(
        now.year,
        now.month,
        now.day,
        widget.task.flexWindowStart!.hour,
        widget.task.flexWindowStart!.minute,
      );
      return now.isAfter(t.subtract(const Duration(minutes: 5)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.isBufferBlock) {
      return AnimatedOpacity(
        opacity: _justCompleted ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _justCompleted
              ? const SizedBox.shrink()
              : Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.appBackground,
                    borderRadius: AppColors.isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: AppColors.isRetro ? 2.0 : 1.0,
                    ),
                    boxShadow: AppColors.isRetro
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
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.textPlaceholder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: AppTypography.bodyText.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss buffer',
                        onPressed: _busy
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                if (widget.onDismissBuffer != null)
                                  _mutate(widget.onDismissBuffer!);
                              },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final isDone = widget.task.status == TaskStatus.done || _justCompleted;
    final isMissed = widget.task.status == TaskStatus.missed;
    final inProgress = widget.task.status == TaskStatus.inProgress;
    final tagType = widget.task.taskType == TaskType.fixed
        ? TagType.fixed
        : (widget.task.taskType == TaskType.floating
              ? TagType.floating
              : TagType.adhoc);
    final tagLabel = widget.task.taskType == TaskType.adhoc
        ? 'One-off'
        : (widget.task.taskType == TaskType.fixed ? 'Fixed' : 'Flexible');

    final timeString = _getTimeString();

    return AbsorbPointer(
      absorbing: _busy,
      child: AnimatedScale(
        scale: _justCompleted ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.cardBackground.withValues(
                    alpha: AppColors.isRetro ? 0.7 : 0.5,
                  )
                : (_isExpanded
                      ? AppColors.cardHoverActive
                      : AppColors.cardBackground),
            borderRadius: AppColors.isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(16),
            border: Border.all(
              color: inProgress
                  ? AppColors.accentPrimary
                  : AppColors.cardBorder,
              width: AppColors.isRetro ? 2.0 : 1.0,
            ),
            boxShadow: AppColors.isRetro
                ? [
                    BoxShadow(
                      color: AppColors.retroShadowColor,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: AppColors.isRetro
                ? BorderRadius.zero
                : BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_busy)
                  const LinearProgressIndicator(semanticsLabel: 'Saving task'),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Tactile Checkbox ──────────────
                              Padding(
                                padding: const EdgeInsets.only(top: 1, right: 10),
                                child: IconButton(
                                  tooltip: isDone
                                      ? 'Completed'
                                      : 'Complete ${widget.task.title}',
                                  onPressed: isDone ? null : _handleCheckboxTap,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  icon: AnimatedScale(
                                    scale: _justCompleted ? 0.88 : 1.0,
                                    duration: const Duration(milliseconds: 120),
                                    curve: Curves.easeOutBack,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: AppColors.isRetro
                                            ? BoxShape.rectangle
                                            : BoxShape.circle,
                                        borderRadius: AppColors.isRetro
                                            ? BorderRadius.zero
                                            : null,
                                        color: isDone
                                            ? AppColors.successDone
                                            : (inProgress
                                                ? AppColors.accentPrimary.withValues(alpha: 0.12)
                                                : (AppColors.isRetro
                                                    ? Colors.transparent
                                                    : (AppColors.isDark
                                                        ? Colors.white.withValues(alpha: 0.04)
                                                        : Colors.black.withValues(alpha: 0.03)))),
                                        border: Border.all(
                                          color: isDone
                                              ? (AppColors.isRetro
                                                    ? AppColors.cardBorder
                                                    : AppColors.successDone)
                                              : (inProgress
                                                    ? AppColors.accentPrimary
                                                    : (AppColors.isRetro
                                                          ? AppColors.cardBorder
                                                          : (AppColors.isDark
                                                                ? Colors.white.withValues(alpha: 0.32)
                                                                : AppColors.textPlaceholder.withValues(alpha: 0.5)))),
                                          width: AppColors.isRetro ? 2.0 : 1.6,
                                        ),
                                      ),
                                      child: isDone
                                          ? Center(
                                              child: Icon(
                                                Icons.check_rounded,
                                                size: 13,
                                                color:
                                                    (AppColors.isRetro &&
                                                        !AppColors.isDark)
                                                    ? AppColors.textPrimary
                                                    : Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),

                              // ── Title & Tags ─────────────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeInOut,
                                      style: AppTypography.cardTitle.copyWith(
                                        color: (isDone || isMissed)
                                            ? AppColors.textMuted
                                            : AppColors.textPrimary,
                                        decoration: (isDone || isMissed)
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: isDone
                                            ? AppColors.textMuted
                                            : AppColors.dangerOverdue,
                                        fontWeight: inProgress
                                            ? FontWeight.w600
                                            : (isDone
                                                  ? FontWeight.w400
                                                  : FontWeight.w500),
                                      ),
                                      child: Text(widget.task.title),
                                    ),
                                    if (inProgress) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Focusing now',
                                        style: AppTypography.cardTime.copyWith(
                                          color: AppColors.accentPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    if (!isDone) ...[
                                      const SizedBox(height: 5),
                                      Wrap(
                                        spacing: 5,
                                        runSpacing: 4,
                                        children: [
                                          TagChip(
                                            type: tagType,
                                            label: tagLabel,
                                          ),
                                          if (widget.task.enableDND)
                                            const TagChip(
                                              type: TagType.dnd,
                                              label: 'DND',
                                            ),
                                          if (isMissed)
                                            const TagChip(
                                              type: TagType.missed,
                                              label: 'Missed',
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 13,
                                          color: inProgress
                                              ? AppColors.accentPrimary
                                              : AppColors.textPlaceholder,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (timeString != null && timeString.isNotEmpty)
                                              ? '$timeString · ${widget.task.durationMinutes} min'
                                              : (widget.task.taskType == TaskType.adhoc
                                                  ? 'Anytime · ${widget.task.durationMinutes} min'
                                                  : (widget.task.flexWindowEnd != null
                                                      ? '~${_formatTime(widget.task.flexWindowEnd)} · ${widget.task.durationMinutes} min'
                                                      : 'Flexible · ${widget.task.durationMinutes} min')),
                                          style: AppTypography.cardTime.copyWith(
                                            fontSize: 11.5,
                                            color: inProgress
                                                ? AppColors.accentPrimary
                                                : AppColors.textPlaceholder,
                                            fontWeight: inProgress
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Trailing Expand Indicator
                              if (!isDone)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 6),
                                  child: AnimatedRotation(
                                    turns: _isExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: AppColors.textPlaceholder,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // ── Expanded Actions Drawer ──────────────────
                          if (_isExpanded) ...[
                            const SizedBox(height: 14),
                            Divider(
                              color: AppColors.isRetro
                                  ? AppColors.cardBorder
                                  : (AppColors.isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : AppColors.dividerBorderHover),
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${widget.task.durationMinutes} mins scheduled · ${widget.task.taskType.name.toUpperCase()}',
                                    style: AppTypography.bodyText.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.task.enableDND) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.do_not_disturb_on_rounded,
                                    size: 13,
                                    color: AppColors.successDone,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DND',
                                    style: AppTypography.tagChip.copyWith(
                                      fontSize: 11,
                                      color: AppColors.successDone,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (inProgress)
                              ActionButton(
                                label: 'Complete Task',
                                isPrimary: true,
                                icon: Icons.check_circle_outline_rounded,
                                onTap: _handleCheckboxTap,
                              )
                            else if (_canStart())
                              ActionButton(
                                label: 'Start Task',
                                isPrimary: true,
                                icon: Icons.play_arrow_rounded,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  if (widget.onStart != null)
                                    _mutate(widget.onStart!);
                                },
                              )
                            else if (widget.task.status == TaskStatus.pending)
                              ActionButton(
                                label: 'Start Early',
                                isPrimary: false,
                                color: AppColors.accentPrimary,
                                icon: Icons.play_arrow_rounded,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  if (widget.onStart != null)
                                    _mutate(widget.onStart!);
                                },
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ActionButton(
                                    label:
                                        widget.task.taskType == TaskType.fixed
                                        ? 'Skip'
                                        : (widget.task.taskType ==
                                                  TaskType.floating
                                              ? 'Log Skipped'
                                              : 'Tomorrow'),
                                    icon: Icons.skip_next_rounded,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (widget.task.taskType ==
                                          TaskType.adhoc) {
                                        final now = DateTime.now();
                                        _mutate(
                                          () => widget.onReschedule(
                                            DateTime(
                                              now.year,
                                              now.month,
                                              now.day + 1,
                                            ),
                                          ),
                                        );
                                      } else {
                                        _mutate(widget.onSkip);
                                      }
                                    },
                                  ),
                                ),
                                if (widget.task.taskType !=
                                    TaskType.floating) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ActionButton(
                                      label: 'Reschedule',
                                      icon: Icons.calendar_today_rounded,
                                      onTap: () async {
                                        final today = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: today,
                                          firstDate: today,
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 30),
                                          ),
                                          builder: (context, child) => Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: Theme.of(context)
                                                  .colorScheme
                                                  .copyWith(
                                                    primary:
                                                        AppColors.accentPrimary,
                                                    surface: AppColors
                                                        .cardBackground,
                                                  ),
                                            ),
                                            child: child!,
                                          ),
                                        );
                                        if (picked != null) {
                                          if (mounted)
                                            await _mutate(
                                              () => widget.onReschedule(picked),
                                            );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Active Live Track Indicator Bar (When inProgress) ───
                if (inProgress)
                  Container(
                    height: 2,
                    color: AppColors.accentPrimary.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
