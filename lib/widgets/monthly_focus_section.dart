import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/simple_goal.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../screens/dashboard/add_focus_screen.dart';

// ─── Seamless infinite marquee ────────────────────────────────────────────────
// Renders items twice. Scrolls through the first copy, then instantly jumps
// back to position 0 (which looks identical to the end of the first copy
// because the second copy is right there). No visible reset.

class _SeamlessMarquee extends StatefulWidget {
  final List<Widget> children;
  const _SeamlessMarquee({required this.children});

  @override
  State<_SeamlessMarquee> createState() => _SeamlessMarqueeState();
}

class _SeamlessMarqueeState extends State<_SeamlessMarquee> {
  final ScrollController _ctrl = ScrollController();
  bool _running = false;
  bool _paused = false;

  // pixels per second
  static const double _speed = 35.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  @override
  void dispose() {
    _running = false;
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loop() async {
    _running = true;
    await Future.delayed(const Duration(milliseconds: 800));

    while (_running && mounted) {
      if (_paused || !_ctrl.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final max = _ctrl.position.maxScrollExtent;
      // maxScrollExtent covers both copies; half = one copy width
      final halfMax = max / 2;

      if (halfMax <= 0) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }

      final current = _ctrl.offset;
      final remaining = halfMax - current;

      if (remaining <= 0) {
        // We've reached the end of the first copy — jump to start seamlessly
        _ctrl.jumpTo(0);
        continue;
      }

      final duration = Duration(milliseconds: (remaining / _speed * 1000).toInt());

      await _ctrl.animateTo(
        halfMax,
        duration: duration,
        curve: Curves.linear,
      );

      if (!mounted) break;

      // Instant jump — second copy looks identical so user sees no cut
      _ctrl.jumpTo(0);
      // Tiny delay before next cycle
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render original + duplicate for seamless wrap
    final doubled = [...widget.children, ...widget.children];

    return Listener(
      onPointerDown: (_) => _paused = true,
      onPointerUp: (_) => _paused = false,
      onPointerCancel: (_) => _paused = false,
      child: ListView.builder(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: doubled.length,
        itemBuilder: (_, i) => doubled[i],
      ),
    );
  }
}

// ─── Section ──────────────────────────────────────────────────────────────────

class MonthlyFocusSection extends StatelessWidget {
  const MonthlyFocusSection({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    Box<SimpleGoal> box,
    int index,
    SimpleGoal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete this item?', style: AppTypography.cardTitle),
        content: Text(goal.title, style: AppTypography.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTypography.bodyText.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTypography.bodyText.copyWith(color: AppColors.errorAlert)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService().cancelFocusReminder(goal.id);
      await box.deleteAt(index);
    }
  }

  Widget _buildChip(BuildContext context, Box<SimpleGoal> box, int i, SimpleGoal goal) {
    final isHabit   = goal.isHabit;
    final borderColor = isHabit ? const Color(0xFFC38714) : AppColors.accentPrimary;
    final iconColor   = isHabit ? const Color(0xFFE5A93D) : const Color(0xFF4C94FA);
    final bgColor     = isHabit
        ? const Color(0xFFC38714).withValues(alpha: 0.1)
        : AppColors.accentPrimary.withValues(alpha: 0.1);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _confirmDelete(context, box, i, goal);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(isHabit ? Icons.loop : Icons.flag, color: iconColor, size: 12),
            ),
            Text(
              goal.title,
              style: AppTypography.tagChip.copyWith(color: const Color(0xFFE0E0E0)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<SimpleGoal>('simple_goals').listenable(),
      builder: (context, Box<SimpleGoal> box, _) {
        final goals = box.values.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MONTHLY FOCUS', style: AppTypography.sectionLabel),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddFocusScreen()),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.add, color: AppColors.accentPrimary, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: goals.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add a goal or habit for this month',
                          style: AppTypography.sectionLabel
                              .copyWith(color: AppColors.textPlaceholder),
                        ),
                      ),
                    )
                  : _SeamlessMarquee(
                      children: goals
                          .asMap()
                          .entries
                          .map((e) => _buildChip(context, box, e.key, e.value))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}
