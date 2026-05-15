import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_providers.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key});

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '0.5');
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    HapticFeedback.mediumImpact();
    double parsedHr = double.tryParse(_durationController.text) ?? 0.5;
    final duration = (parsedHr * 60).round();
    ref.read(todayTasksProvider.notifier).addAdHocTask(title, _selectedTime, duration);
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF252535)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accentPrimary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bottom sheet padding adjustment against keyboard
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF252535), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField('TITLE', _titleController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    'TIME (OPTIONAL)',
                    TextEditingController(text: _selectedTime?.format(context) ?? 'Anytime today'),
                    readOnly: true,
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) setState(() => _selectedTime = time);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField('DURATION (HOURS)', _durationController, isNumber: true),
                ),
              ],
            ),
            const SizedBox(height: 32),
            InkWell(
              onTap: _save,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Save Task',
                  style: AppTypography.buttonLabel.copyWith(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
