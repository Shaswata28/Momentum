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
  final VoidCallback onMarkDone;
  final VoidCallback? onStart;
  final VoidCallback onSkip;
  final void Function(DateTime date) onReschedule;
  final VoidCallback? onDismissBuffer;

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
  bool _justCompleted = false;

  void _toggleExpand() {
    if (widget.task.status == TaskStatus.done || widget.task.isBufferBlock) return;
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
  }

  void _handleCheckboxTap() {
    if (widget.task.status == TaskStatus.done || widget.task.isBufferBlock) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _justCompleted = true;
      _isExpanded = false;
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _justCompleted = false);
      widget.onMarkDone();
    });
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String? _getTimeString() {
    if (widget.task.isBufferBlock) return null;
    if (widget.task.taskType == TaskType.fixed || widget.task.taskType == TaskType.adhoc) {
      return _formatTime(widget.task.scheduledTime);
    } else {
      return widget.task.flexWindowEnd != null
          ? '~${_formatTime(widget.task.flexWindowEnd)}'
          : 'Flexible';
    }
  }

  bool _canStart() {
    if (widget.task.status != TaskStatus.pending) return false;
    final now = DateTime.now();

    if (widget.task.taskType == TaskType.fixed || widget.task.taskType == TaskType.adhoc) {
      if (widget.task.scheduledTime == null) return true;
      final t = DateTime(now.year, now.month, now.day, widget.task.scheduledTime!.hour, widget.task.scheduledTime!.minute);
      return now.isAfter(t.subtract(const Duration(minutes: 5)));
    } else {
      if (widget.task.flexWindowStart == null) return true;
      final t = DateTime(now.year, now.month, now.day, widget.task.flexWindowStart!.hour, widget.task.flexWindowStart!.minute);
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
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.appBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                      Text(
                        widget.task.title,
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _justCompleted = true);
                          Future.delayed(const Duration(milliseconds: 250), () {
                            if (widget.onDismissBuffer != null) widget.onDismissBuffer!();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.textPlaceholder),
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
        : (widget.task.taskType == TaskType.floating ? TagType.floating : TagType.adhoc);
    final tagLabel = widget.task.taskType == TaskType.adhoc
        ? 'One-off'
        : (widget.task.taskType == TaskType.fixed ? 'Fixed' : 'Flexible');

    final timeString = _getTimeString();

    return AnimatedScale(
      scale: _justCompleted ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.cardBackground.withValues(alpha: 0.5)
              : (_isExpanded ? AppColors.cardHoverActive : AppColors.cardBackground),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inProgress
                ? AppColors.accentPrimary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleExpand,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── Tactile Things 3 Checkbox ──────────────
                            GestureDetector(
                              onTap: _handleCheckboxTap,
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedScale(
                                scale: _justCompleted ? 0.88 : 1.0,
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOutBack,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(right: 14),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDone
                                        ? AppColors.successDone
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isDone
                                          ? AppColors.successDone
                                          : (inProgress
                                              ? AppColors.accentPrimary
                                              : Colors.white.withValues(alpha: 0.22)),
                                      width: 1.6,
                                    ),
                                  ),
                                  child: isDone
                                      ? const Center(
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),

                            // ── Title & Tags ─────────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
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
                                          : (isDone ? FontWeight.w400 : FontWeight.w500),
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
                                        TagChip(type: tagType, label: tagLabel),
                                        if (widget.task.enableDND)
                                          const TagChip(type: TagType.dnd, label: 'DND'),
                                        if (isMissed)
                                          const TagChip(type: TagType.missed, label: 'Missed'),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── Time & Duration Pill ─────────────────
                            if (timeString != null && timeString.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeString,
                                          style: AppTypography.cardTime.copyWith(
                                            color: (isDone || isMissed)
                                                ? AppColors.textPlaceholder
                                                : (inProgress ? AppColors.accentPrimary : AppColors.textSecondary),
                                            fontWeight: inProgress ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                        ),
                                        if (!isDone && !isMissed) ...[
                                          const SizedBox(width: 4),
                                          AnimatedRotation(
                                            turns: _isExpanded ? 0.5 : 0.0,
                                            duration: const Duration(milliseconds: 200),
                                            child: Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: _isExpanded
                                                  ? AppColors.accentPrimary
                                                  : AppColors.textPlaceholder,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.task.durationMinutes}m',
                                      style: AppTypography.scoreStat.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textPlaceholder,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        // ── Expanded Actions Drawer ──────────────────
                        if (_isExpanded) ...[
                          const SizedBox(height: 14),
                          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
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
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  _justCompleted = true;
                                  _isExpanded = false;
                                });
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  if (mounted) setState(() => _justCompleted = false);
                                  widget.onMarkDone();
                                });
                              },
                            )
                          else if (widget.task.status == TaskStatus.pending && _canStart())
                            ActionButton(
                              label: 'Start Task',
                              isPrimary: true,
                              icon: Icons.play_arrow_rounded,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() => _isExpanded = false);
                                if (widget.onStart != null) widget.onStart!();
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
                                setState(() => _isExpanded = false);
                                if (widget.onStart != null) widget.onStart!();
                              },
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ActionButton(
                                  label: widget.task.taskType == TaskType.fixed
                                      ? 'Skip'
                                      : (widget.task.taskType == TaskType.floating ? 'Log Skipped' : 'Tomorrow'),
                                  icon: Icons.skip_next_rounded,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _isExpanded = false);
                                    if (widget.task.taskType == TaskType.adhoc) {
                                      widget.onReschedule(DateTime.now().add(const Duration(days: 1)));
                                    } else {
                                      widget.onSkip();
                                    }
                                  },
                                ),
                              ),
                              if (widget.task.taskType != TaskType.floating) ...[
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
                                        lastDate: DateTime.now().add(const Duration(days: 30)),
                                        builder: (context, child) => Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: Theme.of(context).colorScheme.copyWith(
                                              primary: AppColors.accentPrimary,
                                              surface: AppColors.cardBackground,
                                            ),
                                          ),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() => _isExpanded = false);
                                        widget.onReschedule(picked);
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
    );
  }
}
