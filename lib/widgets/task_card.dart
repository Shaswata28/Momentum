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
  final VoidCallback onSkip;
  final void Function(DateTime date) onReschedule;
  final VoidCallback? onDismissBuffer;

  const TaskCard({
    super.key,
    required this.task,
    required this.onMarkDone,
    required this.onSkip,
    required this.onReschedule,
    this.onDismissBuffer,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _justCompleted = false;

  void _toggleExpand() {
    if (widget.task.status == TaskStatus.done || widget.task.isBufferBlock) return;
    HapticFeedback.lightImpact();
    setState(() => _isExpanded = !_isExpanded);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt).toLowerCase();
  }

  Color _getTaskColor() {
    if (widget.task.status == TaskStatus.done) return const Color(0xFF1E1E26);
    if (widget.task.status == TaskStatus.missed) return AppColors.dangerOverdue;
    switch (widget.task.taskType) {
      case TaskType.fixed:
        return AppColors.fixedTask;
      case TaskType.floating:
        return AppColors.floatingTask;
      case TaskType.adhoc:
        return AppColors.adHocTask;
    }
  }

  String? _getTimeString() {
    if (widget.task.isBufferBlock) return null;
    if (widget.task.taskType == TaskType.fixed || widget.task.taskType == TaskType.adhoc) {
      return _formatTime(widget.task.scheduledTime);
    } else {
      return widget.task.flexWindowEnd != null 
          ? '~${_formatTime(widget.task.flexWindowEnd)}'
          : 'floating';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task.isBufferBlock) {
      return AnimatedOpacity(
        opacity: _justCompleted ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _justCompleted ? const SizedBox.shrink() : Container(
            height: 46,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
             decoration: BoxDecoration(
              color: const Color(0xFF0F0F13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A1A24)),
            ),
            child: Row(
              children: [
                Container(width: 2, height: 24, color: const Color(0xFF1A1A24)),
                const SizedBox(width: 14),
                Text(widget.task.title, style: AppTypography.bodyText.copyWith(color: const Color(0xFF2E2E3E), fontSize: 11, fontFamily: 'JetBrains Mono')),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _justCompleted = true);
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (widget.onDismissBuffer != null) widget.onDismissBuffer!();
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close, size: 16, color: Color(0xFF333340)),
                  ),
                ),
              ],
            ),
          )
        ),
      );
    }

    final isDone = widget.task.status == TaskStatus.done || _justCompleted;
    final isMissed = widget.task.status == TaskStatus.missed;
    final tagType = widget.task.taskType == TaskType.fixed ? TagType.fixed : (widget.task.taskType == TaskType.floating ? TagType.floating : TagType.adhoc);
    final tagLabel = widget.task.taskType.name;

    return GestureDetector(
      onTap: _toggleExpand,
      child: AnimatedScale(
        scale: _justCompleted ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isMissed 
              ? const Color(0xFF161111)
              : (_isExpanded ? AppColors.accentTintBackground : AppColors.cardBackground),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone 
                ? const Color(0xFF1D9E75)
                : isMissed 
                    ? AppColors.dangerOverdue.withValues(alpha: 0.3)
                    : (_isExpanded ? AppColors.accentPrimary : const Color(0xFF1A1A24)),
          ),
        ),
        child: Stack(
          children: [
            Opacity(
              opacity: isDone ? 0.8 : (isMissed ? 0.6 : 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 10),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _getTaskColor()),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                style: AppTypography.cardTitle.copyWith(
                                  color: (isDone || isMissed) ? const Color(0xFF444450) : const Color(0xFFD8D8E8),
                                  decoration: (isDone || isMissed) ? TextDecoration.lineThrough : null,
                                  decorationColor: isDone ? const Color(0xFF1D9E75) : (isMissed ? AppColors.dangerOverdue.withValues(alpha: 0.5) : null),
                                ),
                                child: Text(widget.task.title),
                              ),
                              if (!isDone) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    TagChip(type: tagType, label: tagLabel),
                                    if (widget.task.enableDND) const TagChip(type: TagType.dnd, label: 'dnd: on'),
                                    if (isMissed) const TagChip(type: TagType.missed, label: 'missed'),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                        if (_getTimeString() != null)
                          Text(_getTimeString()!, style: AppTypography.cardTime.copyWith(color: (isDone || isMissed) ? const Color(0xFF333340) : AppColors.accentPrimary)),
                      ],
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 12),
                      Container(height: 1, color: const Color(0xFF1A1A24), margin: const EdgeInsets.only(bottom: 12)),
                      Text('Duration: ${widget.task.durationMinutes} min', style: AppTypography.bodyText),
                      const SizedBox(height: 16),
                      // Primary action — full width
                      ActionButton(
                        label: 'Mark done',
                        isPrimary: true,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _justCompleted = true;
                            _isExpanded = false;
                          });
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) setState(() => _justCompleted = false);
                            widget.onMarkDone();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Secondary actions row — always fits
                      Row(
                        children: [
                          Expanded(
                            child: ActionButton(
                              label: widget.task.taskType == TaskType.fixed
                                  ? 'Skip'
                                  : (widget.task.taskType == TaskType.floating ? 'Log skipped' : 'Tomorrow'),
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
                                onTap: () async {
                                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tomorrow,
                                    firstDate: tomorrow,
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                    builder: (context, child) => Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: Color(0xFF6C63FF),
                                          surface: Color(0xFF1A1A24),
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
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
