import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../constants/date_constants.dart';
import '../../models/enums.dart';
import '../../models/routine_task.dart';
import '../../providers/routine_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/retro_typography.dart';
import '../../widgets/app_back_button.dart';

class TaskWizardScreen extends ConsumerStatefulWidget {
  final RoutineTask? existingTask;
  final int? initialDay;

  const TaskWizardScreen({super.key, this.existingTask, this.initialDay});

  @override
  ConsumerState<TaskWizardScreen> createState() => _TaskWizardScreenState();
}

class _TaskWizardScreenState extends ConsumerState<TaskWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _saving = false;
  late final String _taskId = widget.existingTask?.id ?? const Uuid().v4();
  static const int _totalSteps = 6;

  // Step 1: Title
  late final TextEditingController _titleController;
  final List<String> _suggestions = [
    'Deep Work',
    'Morning Workout',
    'Reading',
    'Coding Practice',
    'Meditation',
    'Evening Review',
  ];

  // Step 2: Type
  late TaskType _taskType;

  // Step 3: Days & Times
  late List<int> _selectedDays; // 1=Mon .. 7=Sun
  TimeOfDay? _scheduledTime;
  TimeOfDay? _flexWindowStart;
  TimeOfDay? _flexWindowEnd;

  // Step 4: Duration
  late int _durationMinutes;

  // Step 5: Preferences
  late bool _enableDND;
  late int _bufferMinutes;
  String? _selectedColor;

  static const List<String> _colorOptions = [
    '#388AF6', // Focus Blue
    '#6366F1', // Indigo
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EC4899', // Pink
    '#8B5CF6', // Purple
    '#06B6D4', // Cyan
    '#EF4444', // Coral Red
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;

    _titleController = TextEditingController(text: task?.title ?? '');
    _taskType = task?.taskType ?? TaskType.fixed;

    if (task != null) {
      _selectedDays = List<int>.from(task.daysOfWeek);
    } else if (widget.initialDay != null) {
      _selectedDays = [widget.initialDay!];
    } else {
      _selectedDays = List<int>.from(
        AppDateConstants.workdays,
      ); // Weekdays default (Sun-Thu)
    }

    _scheduledTime = task?.scheduledTime ?? const TimeOfDay(hour: 9, minute: 0);
    _flexWindowStart =
        task?.flexWindowStart ?? const TimeOfDay(hour: 14, minute: 0);
    _flexWindowEnd =
        task?.flexWindowEnd ?? const TimeOfDay(hour: 18, minute: 0);

    _durationMinutes = task?.durationMinutes ?? 45;
    _enableDND = task?.enableDND ?? false;
    _bufferMinutes = task?.bufferAfterMin ?? 5;
    _selectedColor = task?.color ?? _colorOptions[0];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextStep() {
    final isRetro = AppColors.isRetro;
    if (_saving) return;
    if (_currentStep == 0 && _titleController.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a task title.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    color: Colors.white,
                    fontSize: 11.5,
                  )
                : AppTypography.bodyText,
          ),
          backgroundColor: AppColors.errorAlert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
            side: isRetro
                ? BorderSide(color: AppColors.cardBorder, width: 1.5)
                : BorderSide.none,
          ),
        ),
      );
      return;
    }

    if (_currentStep == 2 && _selectedDays.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one day for this routine.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    color: Colors.white,
                    fontSize: 11.5,
                  )
                : AppTypography.bodyText,
          ),
          backgroundColor: AppColors.errorAlert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(10),
            side: isRetro
                ? BorderSide(color: AppColors.cardBorder, width: 1.5)
                : BorderSide.none,
          ),
        ),
      );
      return;
    }

    if (_currentStep == 2 && !_validSchedule()) return;

    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _saveTask();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.pop(context);
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('h:mm a').format(dt);
  }

  Future<void> _pickTime({
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.accentPrimary,
            surface: AppColors.cardBackground,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => onSelected(picked));
    }
  }

  Future<void> _saveTask() async {
    if (_saving || !_validSchedule()) return;
    if (_titleController.text.trim().isEmpty ||
        _selectedDays.isEmpty ||
        _durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a title, at least one day, and a positive duration.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      HapticFeedback.mediumImpact();
      final activePeriod = ref.read(activePeriodProvider);
      final periodId = activePeriod?.id ?? 'default_period';

      final task = RoutineTask(
        id: _taskId,
        title: _titleController.text.trim(),
        taskType: _taskType,
        scheduledTime: _taskType == TaskType.fixed ? _scheduledTime : null,
        flexWindowStart: _taskType == TaskType.floating
            ? _flexWindowStart
            : null,
        flexWindowEnd: _taskType == TaskType.floating ? _flexWindowEnd : null,
        durationMinutes: _durationMinutes,
        daysOfWeek: List<int>.from(_selectedDays)..sort(),
        enableDND: _enableDND,
        bufferAfterMin: _bufferMinutes,
        color: _selectedColor,
        isActive: true,
        routinePeriodId: periodId,
      );

      await ref.read(routineTasksProvider.notifier).saveTask(task);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish saving your routine. Your choices are kept; please retry.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validSchedule() {
    final valid = _taskType == TaskType.fixed
        ? _scheduledTime != null
        : _flexWindowStart != null &&
              _flexWindowEnd != null &&
              _flexWindowEnd!.hour * 60 + _flexWindowEnd!.minute >
                  _flexWindowStart!.hour * 60 + _flexWindowStart!.minute;
    if (!valid)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a scheduled time or a flexible window that ends after it starts.',
          ),
        ),
      );
    return valid;
  }

  Future<void> _deleteTask() async {
    if (widget.existingTask == null) return;
    final isRetro = AppColors.isRetro;
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius:
              isRetro ? BorderRadius.zero : BorderRadius.circular(16),
          side: isRetro
              ? BorderSide(color: AppColors.cardBorder, width: 2.0)
              : BorderSide.none,
        ),
        title: Text(
          isRetro ? 'DELETE ROUTINE TASK?' : 'Delete Routine Task?',
          style: isRetro
              ? RetroTypography.headline.copyWith(fontSize: 12)
              : AppTypography.displayHeading.copyWith(fontSize: 18),
        ),
        content: Text(
          'This routine task will be removed from future schedules.',
          style: isRetro
              ? RetroTypography.bodyText.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                )
              : AppTypography.bodyText.copyWith(
                  color: AppColors.textSecondary,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isRetro ? 'CANCEL' : 'Cancel',
              style: isRetro
                  ? RetroTypography.buttonLabel.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    )
                  : AppTypography.buttonLabel.copyWith(
                      color: AppColors.textMuted,
                    ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isRetro ? 'DELETE' : 'Delete',
              style: isRetro
                  ? RetroTypography.buttonLabel.copyWith(
                      fontSize: 10,
                      color: AppColors.errorAlert,
                    )
                  : AppTypography.buttonLabel.copyWith(
                      color: AppColors.errorAlert,
                    ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(routineTasksProvider.notifier)
          .deleteTask(widget.existingTask!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRetro = AppColors.isRetro;
    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav & Progress Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  AppBackButton(
                    onPressed: _prevStep,
                    margin: const EdgeInsets.only(right: 14),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRetro
                              ? 'STEP ${_currentStep + 1} OF $_totalSteps'
                              : 'Step ${_currentStep + 1} of $_totalSteps',
                          style: isRetro
                              ? RetroTypography.overline.copyWith(
                                  color: AppColors.accentPrimary,
                                  fontSize: 8.5,
                                )
                              : AppTypography.tagChip.copyWith(
                                  color: AppColors.accentPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: isRetro ? 6 : 3.5,
                          decoration: BoxDecoration(
                            color: isRetro
                                ? (AppColors.isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : AppColors.cardBorder
                                        .withValues(alpha: 0.12))
                                : (AppColors.isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06)),
                            borderRadius: isRetro
                                ? BorderRadius.zero
                                : BorderRadius.circular(2),
                            border: isRetro
                                ? Border.all(
                                    color: AppColors.cardBorder,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (widget.existingTask != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: isRetro
                            ? BorderRadius.zero
                            : BorderRadius.circular(10),
                        border: isRetro
                            ? Border.all(
                                color: AppColors.cardBorder,
                                width: 2.0,
                              )
                            : null,
                        boxShadow: isRetro
                            ? [
                                BoxShadow(
                                  color: AppColors.retroShadowColor,
                                  offset: const Offset(2, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: IconButton(
                        tooltip: 'Delete task',
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.errorAlert,
                          size: 20,
                        ),
                        onPressed: _deleteTask,
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                ],
              ),
            ),

            // Step Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _buildStep1Title(),
                  _buildStep2Type(),
                  _buildStep3Schedule(),
                  _buildStep4Duration(),
                  _buildStep5Preferences(),
                  _buildStep6Review(),
                ],
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius:
                      isRetro ? BorderRadius.zero : BorderRadius.circular(14),
                  boxShadow: isRetro
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(2, 2),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: AppColors.accentPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        isRetro ? BorderRadius.zero : BorderRadius.circular(14),
                    side: isRetro
                        ? BorderSide(color: AppColors.cardBorder, width: 2.0)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: _nextStep,
                    child: Center(
                      child: Text(
                        _currentStep == _totalSteps - 1
                            ? (widget.existingTask != null
                                ? (isRetro
                                    ? 'UPDATE TASK ✓'
                                    : 'Update Routine Task ✓')
                                : (isRetro
                                    ? 'SAVE TASK ✓'
                                    : 'Save Routine Task ✓'))
                            : (isRetro ? 'CONTINUE →' : 'Continue →'),
                        style: isRetro
                            ? RetroTypography.buttonLabel.copyWith(
                                fontSize: 11,
                                color: (AppColors.isRetro && !AppColors.isDark)
                                    ? AppColors.textPrimary
                                    : Colors.white,
                              )
                            : AppTypography.buttonLabel.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Title ─────────────────────────────────────────────────────────
  Widget _buildStep1Title() {
    final isRetro = AppColors.isRetro;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRetro ? "WHAT'S THIS TASK CALLED?" : "What's this task called?",
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 13)
                : AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Give your task a clear, motivating name.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius:
                  isRetro ? BorderRadius.zero : BorderRadius.circular(16),
              border: Border.all(
                color: isRetro ? AppColors.cardBorder : AppColors.subtleBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(2, 2),
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isRetro ? 8 : 6,
            ),
            child: TextField(
              controller: _titleController,
              autofocus: true,
              style: isRetro
                  ? RetroTypography.cardTitle.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    )
                  : AppTypography.cardTitle.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
              cursorColor: AppColors.accentPrimary,
              decoration: InputDecoration(
                hintText: 'e.g. Morning Deep Work',
                hintStyle: isRetro
                    ? RetroTypography.bodyText.copyWith(
                        fontSize: 12,
                        color: AppColors.textPlaceholder,
                      )
                    : AppTypography.bodyText.copyWith(
                        color: AppColors.textPlaceholder,
                      ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'SUGGESTIONS',
            style: isRetro
                ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                : AppTypography.sectionLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _titleController.text = suggestion);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(10),
                    border: Border.all(
                      color: isRetro
                          ? AppColors.cardBorder
                          : Colors.white.withValues(alpha: 0.07),
                      width: isRetro ? 1.5 : 1.0,
                    ),
                    boxShadow: isRetro
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(1.5, 1.5),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    suggestion,
                    style: isRetro
                        ? RetroTypography.tagChip.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 10.5,
                          )
                        : AppTypography.tagChip.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Task Type ─────────────────────────────────────────────────────
  Widget _buildStep2Type() {
    final isRetro = AppColors.isRetro;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRetro ? 'WHAT KIND OF TASK?' : 'What kind of task?',
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 13)
                : AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how Momentum should schedule this routine item.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 24),
          _buildTypeOption(
            type: TaskType.fixed,
            icon: Icons.access_time_rounded,
            title: isRetro ? 'FIXED SCHEDULE' : 'Fixed Schedule',
            description:
                'Runs at an exact scheduled time (e.g. 9:00 AM every morning).',
            accentColor: AppColors.fixedTask,
          ),
          const SizedBox(height: 14),
          _buildTypeOption(
            type: TaskType.floating,
            icon: Icons.all_inclusive_rounded,
            title: isRetro ? 'FLEXIBLE WINDOW' : 'Flexible Window',
            description:
                'Can be completed anytime inside an open window (e.g. between 2 PM and 6 PM).',
            accentColor: AppColors.floatingTask,
          ),
          const SizedBox(height: 14),
          _buildTypeOption(
            type: TaskType.adhoc,
            icon: Icons.bolt_rounded,
            title: isRetro ? 'ONE-OFF / AD-HOC' : 'One-off / Ad-hoc',
            description:
                'Single day item or flexible standalone routine block.',
            accentColor: AppColors.adHocTask,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required TaskType type,
    required IconData icon,
    required String title,
    required String description,
    required Color accentColor,
  }) {
    final isRetro = AppColors.isRetro;
    final isDark = AppColors.isDark;
    final isSelected = _taskType == type;

    final cardBg = isSelected
        ? (isRetro
            ? Color.alphaBlend(
                accentColor.withValues(alpha: isDark ? 0.28 : 0.16),
                AppColors.cardBackground,
              )
            : accentColor.withValues(alpha: 0.12))
        : AppColors.cardBackground;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _taskType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius:
              isRetro ? BorderRadius.zero : BorderRadius.circular(16),
          border: Border.all(
            color: isRetro
                ? (isSelected
                    ? (isDark ? accentColor : AppColors.cardBorder)
                    : AppColors.cardBorder)
                : (isSelected
                    ? accentColor
                    : Colors.white.withValues(alpha: 0.08)),
            width: isRetro ? 2.0 : (isSelected ? 1.8 : 1.0),
          ),
          boxShadow: isRetro
              ? [
                  BoxShadow(
                    color: AppColors.retroShadowColor,
                    offset: const Offset(2, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.25 : 0.16),
                borderRadius:
                    isRetro ? BorderRadius.zero : BorderRadius.circular(10),
                border: isRetro
                    ? Border.all(
                        color: accentColor.withValues(alpha: 0.7),
                        width: 1.5,
                      )
                    : null,
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isRetro
                        ? RetroTypography.headline.copyWith(
                            fontSize: 10,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          )
                        : AppTypography.cardTitle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: isRetro
                        ? RetroTypography.bodyText.copyWith(
                            fontSize: 12,
                            color: isSelected
                                ? (isDark
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary)
                                : AppColors.textPlaceholder,
                            height: 1.35,
                          )
                        : AppTypography.bodyText.copyWith(
                            fontSize: 12.5,
                            color: AppColors.textPlaceholder,
                            height: 1.35,
                          ),
                  ),
                ],
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              if (isRetro)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: isDark ? Colors.white : AppColors.cardBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check,
                    size: 15,
                    color: (!isDark && type == TaskType.adhoc)
                        ? AppColors.textPrimary
                        : Colors.white,
                  ),
                )
              else
                Icon(
                  Icons.check_circle_rounded,
                  color: accentColor,
                  size: 20,
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Step 3: Days & Times ──────────────────────────────────────────────────
  Widget _buildStep3Schedule() {
    final isRetro = AppColors.isRetro;
    final days = AppDateConstants.shortDays;
    final dayIndices = AppDateConstants.weekDaysOrder;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRetro ? 'WHEN DOES IT HAPPEN?' : 'When does it happen?',
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 13)
                : AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Select which days this routine runs and specify the time.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 24),

          // Days of the week
          Text(
            'REPEAT ON DAYS',
            style: isRetro
                ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                : AppTypography.sectionLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final dayIndex = dayIndices[i];
              final isSelected = _selectedDays.contains(dayIndex);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(dayIndex);
                    } else {
                      _selectedDays.add(dayIndex);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.cardBackground,
                    shape: isRetro ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isRetro ? BorderRadius.zero : null,
                    border: Border.all(
                      color: isRetro
                          ? AppColors.cardBorder
                          : (isSelected
                              ? AppColors.accentPrimary
                              : Colors.white.withValues(alpha: 0.1)),
                      width: isRetro ? 2.0 : 1.0,
                    ),
                    boxShadow: isRetro
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(1.5, 1.5),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      days[i],
                      style: isRetro
                          ? RetroTypography.tagChip.copyWith(
                              color: isSelected
                                  ? ((!AppColors.isDark && isRetro)
                                      ? AppColors.textPrimary
                                      : Colors.white)
                                  : AppColors.textSecondary,
                              fontSize: 10,
                            )
                          : AppTypography.tagChip.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPresetDayButton(
                isRetro ? 'EVERYDAY' : 'Everyday',
                () => setState(
                  () => _selectedDays = List<int>.from(
                    AppDateConstants.weekDaysOrder,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetDayButton(
                isRetro ? 'WEEKDAYS' : 'Weekdays',
                () => setState(
                  () =>
                      _selectedDays = List<int>.from(AppDateConstants.workdays),
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetDayButton(
                isRetro ? 'WEEKENDS' : 'Weekends',
                () => setState(
                  () => _selectedDays = List<int>.from(
                    AppDateConstants.weekendDays,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Time selection based on type
          if (_taskType == TaskType.fixed) ...[
            Text(
              'SCHEDULED START TIME',
              style: isRetro
                  ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                  : AppTypography.sectionLabel.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
            ),
            const SizedBox(height: 10),
            _buildTimePickerCard(
              label: isRetro ? 'STARTS AT' : 'Starts at',
              timeString: _formatTime(_scheduledTime),
              onTap: () => _pickTime(
                initial: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
                onSelected: (t) => _scheduledTime = t,
              ),
            ),
          ] else if (_taskType == TaskType.floating) ...[
            Text(
              'TIME WINDOW',
              style: isRetro
                  ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                  : AppTypography.sectionLabel.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerCard(
                    label: isRetro ? 'WINDOW OPENS' : 'Window opens',
                    timeString: _formatTime(_flexWindowStart),
                    onTap: () => _pickTime(
                      initial:
                          _flexWindowStart ??
                          const TimeOfDay(hour: 14, minute: 0),
                      onSelected: (t) => _flexWindowStart = t,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePickerCard(
                    label: isRetro ? 'WINDOW CLOSES' : 'Window closes',
                    timeString: _formatTime(_flexWindowEnd),
                    onTap: () => _pickTime(
                      initial:
                          _flexWindowEnd ??
                          const TimeOfDay(hour: 18, minute: 0),
                      onSelected: (t) => _flexWindowEnd = t,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetDayButton(String label, VoidCallback onTap) {
    final isRetro = AppColors.isRetro;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: isRetro ? BorderRadius.zero : BorderRadius.circular(8),
          border: Border.all(
            color: isRetro
                ? AppColors.cardBorder
                : Colors.white.withValues(alpha: 0.06),
            width: isRetro ? 1.5 : 1.0,
          ),
          boxShadow: isRetro
              ? [
                  BoxShadow(
                    color: AppColors.retroShadowColor,
                    offset: const Offset(1.5, 1.5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: isRetro
              ? RetroTypography.tagChip.copyWith(
                  color: AppColors.textPlaceholder,
                  fontSize: 9.5,
                )
              : AppTypography.tagChip.copyWith(
                  color: AppColors.textPlaceholder,
                  fontSize: 11,
                ),
        ),
      ),
    );
  }

  Widget _buildTimePickerCard({
    required String label,
    required String timeString,
    required VoidCallback onTap,
  }) {
    final isRetro = AppColors.isRetro;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius:
              isRetro ? BorderRadius.zero : BorderRadius.circular(16),
          border: Border.all(
            color: isRetro
                ? AppColors.cardBorder
                : Colors.white.withValues(alpha: 0.08),
            width: isRetro ? 2.0 : 1.0,
          ),
          boxShadow: isRetro
              ? [
                  BoxShadow(
                    color: AppColors.retroShadowColor,
                    offset: const Offset(2, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: isRetro
                      ? RetroTypography.overline.copyWith(
                          fontSize: 8,
                          color: AppColors.textPlaceholder,
                        )
                      : AppTypography.tagChip.copyWith(
                          color: AppColors.textPlaceholder,
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeString,
                  style: isRetro
                      ? RetroTypography.cardTime.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        )
                      : AppTypography.cardTime.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ],
            ),
            Icon(
              Icons.edit_calendar_rounded,
              size: 20,
              color: AppColors.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 4: Duration ──────────────────────────────────────────────────────
  Widget _buildStep4Duration() {
    final isRetro = AppColors.isRetro;
    const presets = [15, 30, 45, 60, 90, 120];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRetro ? 'HOW LONG DOES IT TAKE?' : 'How long does it take?',
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 13)
                : AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the allocated duration for this routine block.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 36),

          // Big Duration Display
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isRetro ? 22 : 28,
                vertical: isRetro ? 14 : 18,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius:
                    isRetro ? BorderRadius.zero : BorderRadius.circular(20),
                border: Border.all(
                  color: isRetro
                      ? AppColors.cardBorder
                      : AppColors.accentPrimary.withValues(alpha: 0.3),
                  width: isRetro ? 2.0 : 1.0,
                ),
                boxShadow: isRetro
                    ? [
                        BoxShadow(
                          color: AppColors.retroShadowColor,
                          offset: const Offset(3, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: AppColors.accentPrimary,
                    size: isRetro ? 24 : 28,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isRetro
                        ? '$_durationMinutes MIN'
                        : '$_durationMinutes minutes',
                    style: isRetro
                        ? RetroTypography.titleLarge.copyWith(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          )
                        : AppTypography.displayHeading.copyWith(
                            fontSize: 24,
                            color: AppColors.textPrimary,
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Presets
          Text(
            'QUICK PRESETS',
            style: isRetro
                ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                : AppTypography.sectionLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: presets.map((min) {
              final isSel = _durationMinutes == min;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _durationMinutes = min);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: isRetro ? 14 : 18,
                    vertical: isRetro ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.accentPrimary
                        : AppColors.cardBackground,
                    borderRadius:
                        isRetro ? BorderRadius.zero : BorderRadius.circular(12),
                    border: Border.all(
                      color: isRetro
                          ? AppColors.cardBorder
                          : (isSel
                              ? AppColors.accentPrimary
                              : Colors.white.withValues(alpha: 0.08)),
                      width: isRetro ? 2.0 : 1.0,
                    ),
                    boxShadow: isRetro
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(1.5, 1.5),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '${min}m',
                    style: isRetro
                        ? RetroTypography.tagChip.copyWith(
                            color: isSel
                                ? ((!AppColors.isDark && isRetro)
                                    ? AppColors.textPrimary
                                    : Colors.white)
                                : AppColors.textSecondary,
                            fontSize: 11,
                          )
                        : AppTypography.tagChip.copyWith(
                            color: isSel
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Fine Slider
          Slider(
            value: _durationMinutes.toDouble(),
            min: 10,
            max: 180,
            divisions: 34,
            activeColor: AppColors.accentPrimary,
            inactiveColor: Colors.white.withValues(alpha: 0.1),
            onChanged: (val) {
              setState(() => _durationMinutes = val.toInt());
            },
          ),
        ],
      ),
    );
  }

  // ── Step 5: Preferences & Focus ───────────────────────────────────────────
  Widget _buildStep5Preferences() {
    final isRetro = AppColors.isRetro;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRetro ? 'FOCUS & PREFERENCES' : 'Focus & Preferences',
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 13)
                : AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize distraction-free focus modes and visual styling.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 28),

          // DND Toggle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius:
                  isRetro ? BorderRadius.zero : BorderRadius.circular(16),
              border: Border.all(
                color: isRetro ? AppColors.cardBorder : AppColors.subtleBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(2, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.successDone.withValues(alpha: 0.14),
                    borderRadius:
                        isRetro ? BorderRadius.zero : BorderRadius.circular(10),
                    border: isRetro
                        ? Border.all(
                            color: AppColors.successDone.withValues(alpha: 0.5),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Icon(
                    Icons.do_not_disturb_on_rounded,
                    color: AppColors.successDone,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRetro
                            ? 'DO NOT DISTURB (DND)'
                            : 'Do Not Disturb (DND)',
                        style: isRetro
                            ? RetroTypography.headline.copyWith(
                                fontSize: 9.5,
                                color: AppColors.textPrimary,
                              )
                            : AppTypography.cardTitle.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automatically silence calls and alerts during this task.',
                        style: isRetro
                            ? RetroTypography.bodyText.copyWith(
                                fontSize: 11.5,
                                color: AppColors.textPlaceholder,
                              )
                            : AppTypography.bodyText.copyWith(
                                fontSize: 12,
                                color: AppColors.textPlaceholder,
                              ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _enableDND,
                  activeColor: AppColors.successDone,
                  activeTrackColor: AppColors.successDone.withValues(
                    alpha: 0.4,
                  ),
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _enableDND = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Buffer Time After Task
          Text(
            'BUFFER TIME AFTER TASK',
            style: isRetro
                ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                : AppTypography.sectionLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [0, 5, 10, 15].map((buf) {
              final isSel = _bufferMinutes == buf;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _bufferMinutes = buf);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.accentPrimary
                          : AppColors.cardBackground,
                      borderRadius: isRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(12),
                      border: Border.all(
                        color: isRetro
                            ? AppColors.cardBorder
                            : (isSel
                                ? AppColors.accentPrimary
                                : Colors.white.withValues(alpha: 0.08)),
                        width: isRetro ? 2.0 : 1.0,
                      ),
                      boxShadow: isRetro
                          ? [
                              BoxShadow(
                                color: AppColors.retroShadowColor,
                                offset: const Offset(1.5, 1.5),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        buf == 0 ? 'None' : '${buf}m',
                        style: isRetro
                            ? RetroTypography.tagChip.copyWith(
                                color: isSel
                                    ? ((!AppColors.isDark && isRetro)
                                        ? AppColors.textPrimary
                                        : Colors.white)
                                    : AppColors.textSecondary,
                                fontSize: 11,
                              )
                            : AppTypography.tagChip.copyWith(
                                color: isSel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Color Tag
          Text(
            'TASK ACCENT COLOR',
            style: isRetro
                ? RetroTypography.sectionLabel.copyWith(fontSize: 8.5)
                : AppTypography.sectionLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colorOptions.map((hex) {
              final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
              final isSel = _selectedColor == hex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedColor = hex);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: isRetro ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isRetro ? BorderRadius.zero : null,
                    border: Border.all(
                      color: isRetro
                          ? (isSel ? Colors.white : AppColors.cardBorder)
                          : (isSel ? Colors.white : Colors.transparent),
                      width: isRetro ? (isSel ? 3.0 : 2.0) : 2.5,
                    ),
                    boxShadow: isRetro
                        ? [
                            BoxShadow(
                              color: AppColors.retroShadowColor,
                              offset: const Offset(2, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isSel
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Step 6: Review & Save ─────────────────────────────────────────────────
  Widget _buildStep6Review() {
    final isRetro = AppColors.isRetro;
    const dayMap = {
      7: 'Sun',
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
    };
    final sortedDays = List<int>.from(_selectedDays)
      ..sort((a, b) => (a % 7).compareTo(b % 7));
    final daysStr = sortedDays.map((d) => dayMap[d] ?? '').join(', ');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRetro ? 'REVIEW & CONFIRM' : 'Review & Confirm',
            style: isRetro
                ? RetroTypography.displayHeading.copyWith(fontSize: 13)
                : AppTypography.displayHeading.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 8),
          Text(
            'Here is a summary of your routine task.',
            style: isRetro
                ? RetroTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  )
                : AppTypography.bodyText.copyWith(
                    color: AppColors.textSecondary,
                  ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius:
                  isRetro ? BorderRadius.zero : BorderRadius.circular(18),
              border: Border.all(
                color: isRetro ? AppColors.cardBorder : AppColors.subtleBorder,
                width: isRetro ? 2.0 : 1.0,
              ),
              boxShadow: isRetro
                  ? [
                      BoxShadow(
                        color: AppColors.retroShadowColor,
                        offset: const Offset(3, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _selectedColor != null
                            ? Color(
                                int.parse(
                                  _selectedColor!.replaceFirst('#', '0xFF'),
                                ),
                              )
                            : AppColors.accentPrimary,
                        shape: isRetro ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: isRetro ? BorderRadius.zero : null,
                        border: isRetro
                            ? Border.all(
                                color: AppColors.cardBorder,
                                width: 1.5,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _titleController.text.trim().isEmpty
                            ? 'Untitled Task'
                            : _titleController.text.trim(),
                        style: isRetro
                            ? RetroTypography.cardTitle.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              )
                            : AppTypography.cardTitle.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: isRetro
                            ? BorderRadius.zero
                            : BorderRadius.circular(8),
                        border: isRetro
                            ? Border.all(
                                color: AppColors.accentPrimary,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Text(
                        _taskType.name.toUpperCase(),
                        style: isRetro
                            ? RetroTypography.tagChip.copyWith(
                                color: AppColors.accentPrimary,
                                fontSize: 9,
                              )
                            : AppTypography.tagChip.copyWith(
                                color: AppColors.accentPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isRetro
                      ? AppColors.cardBorder
                      : Colors.white.withValues(alpha: 0.06),
                  height: 1,
                  thickness: isRetro ? 1.5 : 1,
                ),
                const SizedBox(height: 14),

                _buildReviewRow(
                  Icons.calendar_today_rounded,
                  'Repeats on',
                  daysStr,
                ),
                const SizedBox(height: 12),
                if (_taskType == TaskType.fixed)
                  _buildReviewRow(
                    Icons.access_time_rounded,
                    'Time',
                    _formatTime(_scheduledTime),
                  )
                else if (_taskType == TaskType.floating)
                  _buildReviewRow(
                    Icons.all_inclusive_rounded,
                    'Window',
                    '${_formatTime(_flexWindowStart)} – ${_formatTime(_flexWindowEnd)}',
                  ),
                const SizedBox(height: 12),
                _buildReviewRow(
                  Icons.timer_outlined,
                  'Duration',
                  '$_durationMinutes minutes',
                ),
                if (_bufferMinutes > 0) ...[
                  const SizedBox(height: 12),
                  _buildReviewRow(
                    Icons.hourglass_empty_rounded,
                    'Buffer',
                    '$_bufferMinutes minutes after',
                  ),
                ],
                const SizedBox(height: 12),
                _buildReviewRow(
                  Icons.do_not_disturb_on_rounded,
                  'DND Focus',
                  _enableDND ? 'Enabled (Auto-mute)' : 'Disabled',
                  color: _enableDND
                      ? AppColors.successDone
                      : AppColors.textPlaceholder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    final isRetro = AppColors.isRetro;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isRetro ? AppColors.accentPrimary : AppColors.textPlaceholder,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: isRetro
              ? RetroTypography.bodyText.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                )
              : AppTypography.bodyText.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
        ),
        const Spacer(),
        Text(
          value,
          style: isRetro
              ? RetroTypography.cardTitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary,
                )
              : AppTypography.cardTitle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary,
                ),
        ),
      ],
    );
  }
}
