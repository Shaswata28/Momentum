import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';
import '../../models/routine_task.dart';
import '../../models/enums.dart';
import '../../providers/routine_providers.dart';

class TaskEditorSheet extends ConsumerStatefulWidget {
  final RoutineTask? existingTask;
  final int? initialDay; // 1 = Mon

  const TaskEditorSheet({super.key, this.existingTask, this.initialDay});

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _bufferController = TextEditingController();
  
  Set<int> _selectedDays = {};
  TaskType _taskType = TaskType.fixed;
  TimeOfDay? _scheduledTime;
  TimeOfDay? _flexStart;
  TimeOfDay? _flexEnd;
  bool _enableDnd = false;
  String? _selectedColor;

  final List<String> _colors = ['#1A6FE8', '#2A6ECC', '#F5A623', '#1D9E75', '#E24B4A', '#8E44AD'];
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      double drHr = t.durationMinutes / 60.0;
      _durationController.text = drHr == drHr.roundToDouble() ? drHr.toInt().toString() : drHr.toString();
      _bufferController.text = t.bufferAfterMin.toString();
      _selectedDays = Set.from(t.daysOfWeek);
      _taskType = t.taskType;
      _scheduledTime = t.scheduledTime;
      _flexStart = t.flexWindowStart;
      _flexEnd = t.flexWindowEnd;
      _enableDnd = t.enableDND;
      _selectedColor = t.color;
    } else {
      if (widget.initialDay != null) {
        _selectedDays.add(widget.initialDay!);
      }
      _durationController.text = '0.5';
      _bufferController.text = '0';
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) return;
    if (_selectedDays.isEmpty) return;

    HapticFeedback.mediumImpact();
    final activePeriod = ref.read(activePeriodProvider);
    final periodId = activePeriod?.id ?? 'default_period';

    final task = RoutineTask(
      id: widget.existingTask?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      taskType: _taskType,
      daysOfWeek: _selectedDays.toList()..sort(),
      durationMinutes: ((double.tryParse(_durationController.text) ?? 0.5) * 60).round(),
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
    if (widget.existingTask != null) {
      ref.read(routineTasksProvider.notifier).deleteTask(widget.existingTask!.id);
    }
    Navigator.of(context).pop();
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, VoidCallback? onTap, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyText.copyWith(fontSize: 11, color: const Color(0xFF666672))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: AppTypography.bodyText.copyWith(fontSize: 14, color: const Color(0xFFD8D8E8)),
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A24),
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF252535))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentPrimary)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: const Color(0xFF252535), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            
            _buildTextField('TITLE', _titleController),
            const SizedBox(height: 16),
            
            Text('DAYS OF WEEK', style: AppTypography.bodyText.copyWith(fontSize: 11, color: const Color(0xFF666672))),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isSel = _selectedDays.contains(dayNum);
                return GestureDetector(
                  onTap: () => setState(() { isSel ? _selectedDays.remove(dayNum) : _selectedDays.add(dayNum); }),
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSel ? AppColors.accentPrimary : const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(_dayLabels[i], style: TextStyle(color: isSel ? Colors.white : const Color(0xFF888898), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField('DURATION (HOURS)', _durationController, isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('BUFFER AFTER (MIN)', _bufferController, isNumber: true)),
              ],
            ),
            const SizedBox(height: 16),

            Text('TYPE', style: AppTypography.bodyText.copyWith(fontSize: 11, color: const Color(0xFF666672))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: RadioListTile<TaskType>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Fixed', style: AppTypography.bodyText),
                  value: TaskType.fixed,
                  groupValue: _taskType,
                  activeColor: AppColors.accentPrimary,
                  onChanged: (v) => setState(() => _taskType = v!),
                )),
                Expanded(child: RadioListTile<TaskType>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Floating', style: AppTypography.bodyText),
                  value: TaskType.floating,
                  groupValue: _taskType,
                  activeColor: AppColors.accentPrimary,
                  onChanged: (v) => setState(() => _taskType = v!),
                )),
              ],
            ),
            
            if (_taskType == TaskType.fixed)
              _buildTextField('TIME', TextEditingController(text: _scheduledTime?.format(context) ?? 'Pick time'), readOnly: true, onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (t != null) setState(() => _scheduledTime = t);
              })
            else
              Row(
                children: [
                  Expanded(child: _buildTextField('FLEX WINDOW START', TextEditingController(text: _flexStart?.format(context) ?? 'Anytime'), readOnly: true, onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) setState(() => _flexStart = t);
                  })),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('FLEX WINDOW END', TextEditingController(text: _flexEnd?.format(context) ?? 'Anytime'), readOnly: true, onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (t != null) setState(() => _flexEnd = t);
                  })),
                ],
              ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Enable DND', style: AppTypography.bodyText.copyWith(color: const Color(0xFFD8D8E8))),
                Switch(
                  value: _enableDnd,
                  activeColor: AppColors.accentPrimary,
                  onChanged: (v) => setState(() => _enableDnd = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text('COLOR TAG (OPTIONAL)', style: AppTypography.bodyText.copyWith(fontSize: 11, color: const Color(0xFF666672))),
            const SizedBox(height: 8),
            Row(
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColor = _selectedColor == c ? null : c),
                child: Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(color: _selectedColor == c ? Colors.white : Colors.transparent, width: 2),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                if (widget.existingTask != null) ...[
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: _delete,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 48, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.dangerOverdue, width: 1),
                        ),
                        child: Text('Delete', style: AppTypography.buttonLabel.copyWith(fontSize: 14, color: AppColors.dangerOverdue)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _save,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(12)),
                      child: Text('Save Routine Task', style: AppTypography.buttonLabel.copyWith(fontSize: 14)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
