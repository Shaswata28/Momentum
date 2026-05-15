import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';
import '../../models/routine_task.dart';
import '../../models/enums.dart';
import '../../providers/routine_providers.dart';

class TaskEditorSheet extends ConsumerStatefulWidget {
  final RoutineTask? existingTask;
  final int? initialDay;
  final bool isDuplicate;

  const TaskEditorSheet({
    super.key,
    this.existingTask,
    this.initialDay,
    this.isDuplicate = false,
  });

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  final _titleController = TextEditingController();
  final _bufferController = TextEditingController();
  final _titleFocus = FocusNode();

  Set<int> _selectedDays = {};
  TaskType _taskType = TaskType.fixed;
  TimeOfDay? _scheduledTime;
  TimeOfDay? _flexStart;
  TimeOfDay? _flexEnd;
  bool _enableDnd = false;
  String? _selectedColor;
  int _durationMinutes = 30;
  bool _titleError = false;
  bool _daysError = false;

  final List<String> _colors = [
    '#1A6FE8', '#2A6ECC', '#F5A623', '#1D9E75', '#E24B4A', '#8E44AD',
    '#00BCD4', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0', '#607D8B'
  ];
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final List<int> _quickDurations = [15, 30, 45, 60, 90, 120];

  Future<void> _showCustomDurationPicker() async {
    int h = _durationMinutes ~/ 60;
    int m = _durationMinutes % 60;
    final hController = TextEditingController(text: h > 0 ? h.toString() : '');
    final mController = TextEditingController(text: m > 0 ? m.toString() : '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161619),
        title: Text('Custom Duration', style: AppTypography.displayHeading.copyWith(fontSize: 18)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hController,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyText,
                decoration: InputDecoration(
                  labelText: 'Hours',
                  labelStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF1E1E26),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: mController,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyText,
                decoration: InputDecoration(
                  labelText: 'Minutes',
                  labelStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF1E1E26),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.buttonLabel.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPrimary),
            onPressed: () {
              int parsedH = int.tryParse(hController.text) ?? 0;
              int parsedM = int.tryParse(mController.text) ?? 0;
              int total = (parsedH * 60) + parsedM;
              if (total > 0) {
                setState(() => _durationMinutes = total);
              }
              Navigator.pop(ctx);
            },
            child: Text('Apply', style: AppTypography.buttonLabel),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _durationMinutes = t.durationMinutes;
      _bufferController.text = t.bufferAfterMin.toString();
      _selectedDays = widget.isDuplicate ? {} : Set.from(t.daysOfWeek);
      _taskType = t.taskType;
      _scheduledTime = t.scheduledTime;
      _flexStart = t.flexWindowStart;
      _flexEnd = t.flexWindowEnd;
      _enableDnd = t.enableDND;
      _selectedColor = t.color;
    } else {
      if (widget.initialDay != null) _selectedDays.add(widget.initialDay!);
      _bufferController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bufferController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt).toLowerCase();
  }

  String _durationLabel(int min) {
    if (min < 60) return '${min}m';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String? _previewTimeRange() {
    if (_taskType == TaskType.fixed && _scheduledTime != null) {
      final endMin = _scheduledTime!.hour * 60 + _scheduledTime!.minute + _durationMinutes;
      final end = TimeOfDay(hour: (endMin ~/ 60) % 24, minute: endMin % 60);
      return '${_formatTime(_scheduledTime)} – ${_formatTime(end)}';
    }
    if (_taskType == TaskType.floating && _flexStart != null && _flexEnd != null) {
      return '${_formatTime(_flexStart)} – ${_formatTime(_flexEnd)} window';
    }
    return null;
  }

  List<String> _checkConflicts() {
    final tasks = ref.read(routineTasksProvider);
    if (_scheduledTime == null || _taskType != TaskType.fixed) return [];
    final startMin = _scheduledTime!.hour * 60 + _scheduledTime!.minute;
    final endMin = startMin + _durationMinutes;
    final conflicts = <String>[];
    for (final t in tasks) {
      if (widget.existingTask != null && !widget.isDuplicate && t.id == widget.existingTask!.id) continue;
      if (t.taskType != TaskType.fixed || t.scheduledTime == null) continue;
      final tStart = t.scheduledTime!.hour * 60 + t.scheduledTime!.minute;
      final tEnd = tStart + t.durationMinutes;
      final sharedDays = _selectedDays.where((d) => t.daysOfWeek.contains(d)).toList();
      if (sharedDays.isEmpty) continue;
      if (startMin < tEnd && endMin > tStart) {
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayStr = sharedDays.map((d) => dayNames[d - 1]).join(', ');
        conflicts.add('"${t.title}" on $dayStr');
      }
    }
    return conflicts;
  }

  void _save() {
    final titleEmpty = _titleController.text.trim().isEmpty;
    final noDays = _selectedDays.isEmpty;
    if (titleEmpty || noDays) {
      setState(() {
        _titleError = titleEmpty;
        _daysError = noDays;
      });
      HapticFeedback.heavyImpact();
      if (titleEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(noDays ? 'Enter a title and pick at least one day' : 'Enter a task title'),
          backgroundColor: AppColors.errorAlert,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick at least one day'),
          backgroundColor: AppColors.errorAlert,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final activePeriod = ref.read(activePeriodProvider);
    final periodId = activePeriod?.id ?? 'default_period';
    final isNew = widget.existingTask == null || widget.isDuplicate;

    final task = RoutineTask(
      id: isNew ? const Uuid().v4() : widget.existingTask!.id,
      title: _titleController.text.trim(),
      taskType: _taskType,
      daysOfWeek: _selectedDays.toList()..sort(),
      durationMinutes: _durationMinutes,
      scheduledTime: _scheduledTime,
      flexWindowStart: _flexStart,
      flexWindowEnd: _flexEnd,
      bufferAfterMin: int.tryParse(_bufferController.text) ?? 0,
      enableDND: _enableDnd,
      color: _selectedColor,
      isActive: true,
      routinePeriodId: periodId,
    );

    ref.read(routineTasksProvider.notifier).saveTask(task);
    Navigator.of(context).pop();
  }

  void _delete() {
    HapticFeedback.heavyImpact();
    if (widget.existingTask != null && !widget.isDuplicate) {
      ref.read(routineTasksProvider.notifier).deleteTask(widget.existingTask!.id);
    }
    Navigator.of(context).pop();
  }

  void _duplicate() {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskEditorSheet(existingTask: widget.existingTask, isDuplicate: true),
    );
  }

  Future<void> _pickTime({required ValueChanged<TimeOfDay> onPicked, TimeOfDay? initial}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            surface: Color(0xFF1A1A24),
          ),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => onPicked(t));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final conflicts = _checkConflicts();
    final preview = _previewTimeRange();
    final isEditing = widget.existingTask != null && !widget.isDuplicate;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: AppColors.appBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A38),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Text(
              widget.isDuplicate ? 'Duplicate Task' : (isEditing ? 'Edit Task' : 'New Task'),
              style: AppTypography.displayHeading,
            ),
            const SizedBox(height: 24),

            // ── Title ──────────────────────────────────────────────────────
            Text('TITLE', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF121217),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _titleError ? AppColors.errorAlert : const Color(0xFF1E1E26),
                ),
              ),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                textCapitalization: TextCapitalization.words,
                style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
                onChanged: (_) { if (_titleError) setState(() => _titleError = false); },
                decoration: InputDecoration(
                  hintText: 'e.g. Study Math, Exercise...',
                  hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Days ───────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DAYS', style: AppTypography.sectionLabel),
                Row(
                  children: [
                    _QuickDayChip(
                      label: 'Weekdays',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectedDays = {1, 2, 3, 4, 5};
                          _daysError = false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _QuickDayChip(
                      label: 'Everyday',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectedDays = {1, 2, 3, 4, 5, 6, 7};
                          _daysError = false;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isSel = _selectedDays.contains(dayNum);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      isSel ? _selectedDays.remove(dayNum) : _selectedDays.add(dayNum);
                      if (_daysError) _daysError = false;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40, height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.accentPrimary.withValues(alpha: 0.2)
                          : const Color(0xFF121217),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _daysError
                            ? AppColors.errorAlert.withValues(alpha: 0.6)
                            : (isSel ? AppColors.accentPrimary : const Color(0xFF1E1E26)),
                      ),
                    ),
                    child: Text(
                      _dayLabels[i],
                      style: AppTypography.buttonLabel.copyWith(
                        fontSize: 13,
                        color: isSel ? AppColors.accentPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Type toggle (surfaced to main view) ────────────────────────
            Text('TYPE', style: AppTypography.sectionLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                _TypeTab(
                  label: 'Fixed Time',
                  icon: Icons.schedule,
                  active: _taskType == TaskType.fixed,
                  onTap: () => setState(() => _taskType = TaskType.fixed),
                ),
                const SizedBox(width: 8),
                _TypeTab(
                  label: 'Floating',
                  icon: Icons.swap_vert_rounded,
                  active: _taskType == TaskType.floating,
                  onTap: () => setState(() => _taskType = TaskType.floating),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Time / Window ──────────────────────────────────────────────
            Row(
              children: [
                Text(
                  _taskType == TaskType.fixed ? 'SCHEDULED TIME' : 'TIME WINDOW',
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(width: 6),
                Text(
                  '(optional)',
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.textMuted, fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_taskType == TaskType.fixed) ...[
              // Fixed: single time row with clear button
              GestureDetector(
                onTap: () => _pickTime(
                  onPicked: (t) => setState(() => _scheduledTime = t),
                  initial: _scheduledTime,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121217),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _scheduledTime != null
                          ? AppColors.accentPrimary.withValues(alpha: 0.4)
                          : const Color(0xFF1E1E26),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: _scheduledTime != null ? AppColors.accentPrimary : AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _scheduledTime != null ? _formatTime(_scheduledTime) : 'Tap to set time',
                          style: AppTypography.bodyText.copyWith(
                            fontSize: 15,
                            fontWeight: _scheduledTime != null ? FontWeight.w600 : FontWeight.normal,
                            color: _scheduledTime != null ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (_scheduledTime != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _scheduledTime = null);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A38),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.close, size: 13, color: AppColors.textMuted),
                          ),
                        )
                      else
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Floating: unified from → to row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF121217),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_flexStart != null || _flexEnd != null)
                        ? AppColors.accentPrimary.withValues(alpha: 0.4)
                        : const Color(0xFF1E1E26),
                  ),
                ),
                child: Row(
                  children: [
                    // Start
                    GestureDetector(
                      onTap: () => _pickTime(onPicked: (t) => setState(() => _flexStart = t), initial: _flexStart),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              color: _flexStart != null ? AppColors.accentPrimary : AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _flexStart != null ? _formatTime(_flexStart) : 'Anytime',
                            style: AppTypography.bodyText.copyWith(
                              fontSize: 14,
                              fontWeight: _flexStart != null ? FontWeight.w600 : FontWeight.normal,
                              color: _flexStart != null ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                          if (_flexStart != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () { HapticFeedback.lightImpact(); setState(() => _flexStart = null); },
                              child: const Icon(Icons.close, size: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Arrow divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward,
                          size: 14, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    ),
                    // End
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(onPicked: (t) => setState(() => _flexEnd = t), initial: _flexEnd),
                        child: Row(
                          children: [
                            Text(
                              _flexEnd != null ? _formatTime(_flexEnd) : 'Anytime',
                              style: AppTypography.bodyText.copyWith(
                                fontSize: 14,
                                fontWeight: _flexEnd != null ? FontWeight.w600 : FontWeight.normal,
                                color: _flexEnd != null ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                            if (_flexEnd != null) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () { HapticFeedback.lightImpact(); setState(() => _flexEnd = null); },
                                child: const Icon(Icons.close, size: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Duration quick-pick ────────────────────────────────────────
            Text('DURATION', style: AppTypography.sectionLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ..._quickDurations.map((min) {
                  final active = _durationMinutes == min;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _durationMinutes = min);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.accentPrimary.withValues(alpha: 0.15)
                            : const Color(0xFF121217),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppColors.accentPrimary.withValues(alpha: 0.6)
                              : const Color(0xFF1E1E26),
                        ),
                      ),
                      child: Text(
                        _durationLabel(min),
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 13,
                          color: active ? AppColors.accentPrimary : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                
                // + Custom Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showCustomDurationPicker();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_quickDurations.contains(_durationMinutes)
                          ? AppColors.accentPrimary.withValues(alpha: 0.15)
                          : const Color(0xFF121217),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: !_quickDurations.contains(_durationMinutes)
                            ? AppColors.accentPrimary.withValues(alpha: 0.6)
                            : const Color(0xFF1E1E26),
                      ),
                    ),
                    child: Text(
                      !_quickDurations.contains(_durationMinutes)
                          ? 'Custom: ${_durationLabel(_durationMinutes)}'
                          : '+ Custom',
                      style: AppTypography.bodyText.copyWith(
                        fontSize: 13,
                        color: !_quickDurations.contains(_durationMinutes) ? AppColors.accentPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Duration preview pill — shown below chips
            if (preview != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AppColors.accentPrimary),
                    const SizedBox(width: 6),
                    Text(preview, style: AppTypography.sectionLabel.copyWith(
                      color: AppColors.accentPrimary, fontSize: 11,
                    )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Advanced Options ───────────────────────────────────────────
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: AppColors.textMuted,
                iconColor: AppColors.accentPrimary,
                title: Text('⚙️ Advanced Options', style: AppTypography.sectionLabel),
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 10),
                children: [
                  // (Type toggle is now in the main view)
                  
                  // ── Buffer
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('BUFFER AFTER (MINUTES)', style: AppTypography.sectionLabel)
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121217),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E1E26)),
                    ),
                    child: TextField(
                      controller: _bufferController,
                      keyboardType: TextInputType.number,
                      style: AppTypography.bodyText.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: AppTypography.bodyText.copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── DND toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121217),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E1E26)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.do_not_disturb_on_outlined,
                                color: _enableDnd ? AppColors.warningTag : AppColors.textMuted, size: 18),
                            const SizedBox(width: 12),
                            Text('Do Not Disturb', style: AppTypography.bodyText.copyWith(
                              color: _enableDnd ? AppColors.textPrimary : AppColors.textSecondary,
                            )),
                          ],
                        ),
                        Switch(
                          value: _enableDnd,
                          activeThumbColor: AppColors.accentPrimary,
                          onChanged: (v) => setState(() => _enableDnd = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Color tag
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('COLOR TAG', style: AppTypography.sectionLabel)
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // "None" option
                      GestureDetector(
                        onTap: () => setState(() => _selectedColor = null),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E1E26),
                            border: Border.all(
                              color: _selectedColor == null ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: _selectedColor == null
                              ? const Icon(Icons.close, size: 14, color: AppColors.textMuted)
                              : null,
                        ),
                      ),
                      ..._colors.map((c) => GestureDetector(
                        onTap: () => setState(() => _selectedColor = c),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == c ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),

            // ── Conflict warning ───────────────────────────────────────────
            if (conflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningTag.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warningTag.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warningTag, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Overlaps with ${conflicts.join(', ')}',
                        style: AppTypography.bodyText.copyWith(
                          color: AppColors.warningTag, fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ── Action buttons ─────────────────────────────────────────────
            GestureDetector(
              onTap: _save,
              child: Container(
                height: 48, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEditing ? 'Update Task' : 'Save Task',
                  style: AppTypography.buttonLabel.copyWith(fontSize: 14),
                ),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _duplicate,
                      child: Container(
                        height: 44, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.copy, size: 16, color: AppColors.accentPrimary),
                            const SizedBox(width: 8),
                            Text('Duplicate', style: AppTypography.buttonLabel.copyWith(
                              fontSize: 13, color: AppColors.accentPrimary,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _delete,
                      child: Container(
                        height: 44, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.errorAlert.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.errorAlert.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delete_outline, size: 16, color: AppColors.errorAlert),
                            const SizedBox(width: 8),
                            Text('Delete', style: AppTypography.buttonLabel.copyWith(
                              fontSize: 13, color: AppColors.errorAlert,
                            )),
                          ],
                        ),
                      ),
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
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.accentPrimary.withValues(alpha: 0.12) : const Color(0xFF121217),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.accentPrimary : const Color(0xFF1E1E26),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? AppColors.accentPrimary : AppColors.textMuted),
              const SizedBox(width: 8),
              Text(label, style: AppTypography.buttonLabel.copyWith(
                fontSize: 13, color: active ? AppColors.accentPrimary : AppColors.textMuted,
              )),
            ],
          ),
        ),
      ),
    );
  }
}



class _QuickDayChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickDayChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: AppTypography.sectionLabel.copyWith(
            color: AppColors.accentPrimary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

