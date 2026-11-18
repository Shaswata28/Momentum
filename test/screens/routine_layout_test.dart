import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:momentum/constants/date_constants.dart';
import 'package:momentum/models/enums.dart';
import 'package:momentum/models/routine_period.dart';
import 'package:momentum/models/routine_task.dart';
import 'package:momentum/models/time_of_day_adapter.dart';
import 'package:momentum/providers/routine_providers.dart';
import 'package:momentum/repositories/routine_task_repository.dart';
import 'package:momentum/screens/routine/routine_builder_screen.dart';
import 'package:momentum/screens/routine/task_block.dart';
import 'package:momentum/screens/routine/task_wizard_screen.dart';
import 'package:momentum/theme/app_colors.dart';
import 'package:momentum/theme/app_theme.dart';
import 'package:momentum/theme/retro_theme.dart';

// Read real Hive fixtures, but isolate delete UI from disk/dashboard services.
class _PlannerNotifier extends RoutineTasksNotifier {
  _PlannerNotifier(super.repo, super.activePeriodId, super.ref);
  String? deletedId;

  @override
  Future<void> deleteTask(String id) async {
    deletedId = id;
    state = state.where((task) => task.id != id).toList();
  }
}

void main() {
  late Directory directory;
  late Box<RoutineTask> box;
  late _PlannerNotifier notifier;
  final period = RoutinePeriod(
    id: 'test-period',
    label: 'A long semester routine for study, recovery and personal projects',
    startDate: DateTime(2026),
    endDate: DateTime(2027),
    isActive: true,
  );

  RoutineTask task(int index) => RoutineTask(
    id: 'task-$index',
    title: 'Focused study and a very long project preparation title $index',
    taskType: index.isEven ? TaskType.fixed : TaskType.floating,
    scheduledTime: index.isEven ? TimeOfDay(hour: index, minute: 30) : null,
    durationMinutes: 125,
    daysOfWeek: index.isEven
        ? List.of(AppDateConstants.workdays)
        : List.of(AppDateConstants.weekendDays),
    enableDND: true,
    bufferAfterMin: 5,
    color: index == 0 ? '#388AF6' : null,
    isActive: true,
    routinePeriodId: period.id,
  );

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    directory = await Directory.systemTemp.createTemp('routine_layout_');
    Hive.init(directory.path);
    Hive.registerAdapter(TaskTypeAdapter());
    Hive.registerAdapter(TimeOfDayAdapter());
    Hive.registerAdapter(RoutineTaskAdapter());
    box = await Hive.openBox<RoutineTask>('routineTasks');
  });

  tearDownAll(() async {
    AppColors.isRetro = false;
    AppColors.isDark = true;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester,
    double scale, {
    bool empty = false,
  }) async {
    await tester.runAsync(() async {
      await box.clear();
      if (!empty) {
        await box.putAll({for (var i = 0; i < 12; i++) 'task-$i': task(i)});
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePeriodProvider.overrideWithValue(empty ? null : period),
          routineTasksProvider.overrideWith(
            (ref) => notifier = _PlannerNotifier(
              RoutineTaskRepository(),
              period.id,
              ref,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppColors.isRetro
              ? (AppColors.isDark
                    ? RetroTheme.darkTheme
                    : RetroTheme.lightTheme)
              : (AppColors.isDark ? AppTheme.darkTheme : AppTheme.lightTheme),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const RoutineBuilderScreen(),
                  ),
                ),
                child: const Text('Open planner'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open planner'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  void expectTarget(WidgetTester tester, Finder finder) {
    final size = tester.getSize(finder);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  }

  Future<void> scrollDay(WidgetTester tester, int day) async {
    final column = find.byKey(ValueKey('routine-day-$day'));
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: column, matching: find.byType(Scrollable)),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    while (scroll.position.extentAfter > 0) {
      scroll.position.jumpTo(
        (scroll.position.pixels + 200).clamp(
          0,
          scroll.position.maxScrollExtent,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  }

  for (final retro in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'Planner retro=$retro dark=$dark width=$width scale=$scale',
            (tester) async {
              AppColors.isRetro = retro;
              AppColors.isDark = dark;
              await tester.binding.setSurfaceSize(Size(width, 800));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final semantics = tester.ensureSemantics();
              try {
                await mount(tester, scale);
                expect(find.text(period.label), findsOneWidget);
                expect(find.byType(FittedBox), findsNothing);
                final dayHeader = tester.widget<Container>(
                  find
                      .descendant(
                        of: find.byKey(const ValueKey('routine-day-7')),
                        matching: find.byWidgetPredicate(
                          (widget) =>
                              widget is Container &&
                              widget.decoration is BoxDecoration,
                        ),
                      )
                      .first,
                );
                final decoration = dayHeader.decoration! as BoxDecoration;
                expect(
                  decoration.borderRadius,
                  BorderRadius.circular(retro ? 0 : 12),
                );
                expect((decoration.border! as Border).top.width, retro ? 2 : 1);
                expectTarget(tester, find.byTooltip('Back'));
                expect(
                  tester
                      .getSemantics(find.byTooltip('Back'))
                      .hasFlag(SemanticsFlag.isButton),
                  isTrue,
                );

                final horizontal = tester.state<ScrollableState>(
                  find.byType(Scrollable).first,
                );
                var previousX = double.negativeInfinity;
                for (final (index, day)
                    in AppDateConstants.weekDaysOrder.indexed) {
                  final column = find.byKey(ValueKey('routine-day-$day'));
                  final x =
                      tester.getTopLeft(column).dx + horizontal.position.pixels;
                  expect(x, greaterThan(previousX));
                  previousX = x;
                  horizontal.position.jumpTo(
                    (x - 20).clamp(0, horizontal.position.maxScrollExtent),
                  );
                  await tester.pump();
                  final expectedIds = [
                    for (var i = 0; i < 12; i++)
                      if (task(i).daysOfWeek.contains(day)) 'task-$i',
                  ];
                  expect(
                    tester
                        .widgetList<TaskBlock>(
                          find.descendant(
                            of: column,
                            matching: find.byType(TaskBlock),
                          ),
                        )
                        .map((block) => block.task.id),
                    day == 5 || day == 6
                        ? unorderedEquals(expectedIds)
                        : expectedIds,
                  );
                  await scrollDay(tester, day);
                  final add = find.byKey(ValueKey('routine-add-$day'));
                  await tester.ensureVisible(add);
                  await tester.pumpAndSettle();
                  expectTarget(tester, add);
                  expect(
                    tester.getSemantics(add).getSemanticsData().tooltip,
                    'Add task for ${AppDateConstants.shortDays[index]}',
                  );
                  await tester.tap(add);
                  await tester.pumpAndSettle();
                  expect(
                    tester
                        .widget<TaskWizardScreen>(find.byType(TaskWizardScreen))
                        .initialDay,
                    day,
                  );
                  expect(tester.takeException(), isNull);
                  Navigator.of(
                    tester.element(find.byType(TaskWizardScreen)),
                  ).pop();
                  await tester.pumpAndSettle();
                }

                horizontal.position.jumpTo(0);
                final sunday = find.byKey(const ValueKey('routine-day-7'));
                final vertical = tester.state<ScrollableState>(
                  find.descendant(
                    of: sunday,
                    matching: find.byType(Scrollable),
                  ),
                );
                vertical.position.jumpTo(0);
                await tester.pump();
                final block = find
                    .descendant(of: sunday, matching: find.byType(TaskBlock))
                    .first;
                expectTarget(tester, block);
                await tester.tap(block);
                await tester.pumpAndSettle();
                expect(
                  tester
                      .widget<TaskWizardScreen>(find.byType(TaskWizardScreen))
                      .existingTask
                      ?.id,
                  'task-0',
                );
                final delete = find.widgetWithIcon(
                  IconButton,
                  Icons.delete_outline_rounded,
                );
                expectTarget(tester, delete);
                await tester.tap(delete);
                await tester.pumpAndSettle();
                expect(find.text('Delete Routine Task?'), findsOneWidget);
                expectTarget(tester, find.widgetWithText(TextButton, 'Cancel'));
                expectTarget(tester, find.widgetWithText(TextButton, 'Delete'));
                await tester.tap(find.text('Cancel'));
                await tester.pumpAndSettle();
                expect(box.containsKey('task-0'), isTrue);
                expect(tester.takeException(), isNull);
                await tester.tap(delete);
                await tester.pumpAndSettle();
                await tester.tap(find.widgetWithText(TextButton, 'Delete'));
                await tester.pumpAndSettle();
                expect(notifier.deletedId, 'task-0');
                expect(find.byType(TaskWizardScreen), findsNothing);
                expect(
                  find.descendant(
                    of: sunday,
                    matching: find.text(task(0).title),
                  ),
                  findsNothing,
                );
                await tester.tap(find.byTooltip('Back'));
                await tester.pumpAndSettle();
                expect(find.text('Open planner'), findsOneWidget);
                expect(tester.takeException(), isNull);
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }

  for (final retro in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('Empty planner retro=$retro dark=$dark at 320/2x', (
        tester,
      ) async {
        AppColors.isRetro = retro;
        AppColors.isDark = dark;
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await mount(tester, 2, empty: true);
        expect(find.text('General Routine'), findsOneWidget);
        expect(find.text('0 tasks'), findsOneWidget);
        expect(find.byType(TaskBlock), findsNothing);
        final horizontal = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        for (final day in AppDateConstants.weekDaysOrder) {
          final add = find.byKey(ValueKey('routine-add-$day'));
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          expectTarget(tester, add);
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TaskWizardScreen>(find.byType(TaskWizardScreen))
                .initialDay,
            day,
          );
          Navigator.of(tester.element(find.byType(TaskWizardScreen))).pop();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(horizontal.position.pixels, greaterThan(0));
      });
    }
  }
}
