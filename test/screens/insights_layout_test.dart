import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/eod_log.dart';
import 'package:momentum/models/transaction.dart';
import 'package:momentum/models/wallet_settings.dart';
import 'package:momentum/providers/review_providers.dart';
import 'package:momentum/providers/wallet_providers.dart';
import 'package:momentum/screens/insights/insights_screen.dart';
import 'package:momentum/screens/log/review_history_screen.dart';
import 'package:momentum/theme/app_colors.dart';

void main() {
  late Directory directory;
  final now = DateTime.now();
  final logs = List.generate(35, (index) {
    final day = DateTime(now.year, now.month, now.day - index);
    return EODLog(
      id: 'review-$index',
      date: day,
      closedAt: day,
      totalTasks: 12,
      completedTasks: 10,
      skippedTasks: 1,
      rescheduledTasks: 1,
      healthScore: 83.3,
      grade: 'B',
      energyLevel: 8,
      motivation: 'A populated daily reflection',
      stuckToBudget: index.isEven,
    );
  });
  final transactions = [
    for (final (index, type) in ExpenseType.values.indexed)
      Transaction(
        id: 'expense-$index',
        date: now,
        direction: Direction.expense,
        expenseType: type,
        amount: 123456789.12,
        monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      ),
  ];

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    directory = await Directory.systemTemp.createTemp('insights_layout_');
    Hive.init(directory.path);
    Hive.registerAdapter(EODLogAdapter());
    Hive.registerAdapter(WalletSettingsAdapter());
    await Hive.openBox<EODLog>('eodLogs');
    await Hive.openBox<WalletSettings>('walletSettings');
    await Hive.box<EODLog>(
      'eodLogs',
    ).putAll({for (final log in logs) log.id: log});
    await Hive.box<WalletSettings>('walletSettings').put(
      'settings',
      WalletSettings(monthlyBudget: 987654321.12, semesterGoal: 999999999.99),
    );
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
    bool reducedMotion = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewHistoryProvider.overrideWith((ref) => Stream.value(logs)),
          localTimeProvider.overrideWith((ref) => Stream.value(now)),
          currentTransactionsProvider.overrideWithValue(transactions),
          monthlyTotalsProvider.overrideWithValue(
            const MonthlyTotals(
              totalIncome: 987654321.12,
              totalExpense: 123456789.12,
              netSavings: 864197532,
            ),
          ),
          dailySpendingProvider.overrideWithValue({
            1: 123456789.12,
            now.day: 98765432.1,
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(
            brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }

  Future<void> scrollEntireView(WidgetTester tester) async {
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    while (scrollable.position.pixels < scrollable.position.maxScrollExtent) {
      scrollable.position.jumpTo(
        (scrollable.position.pixels + 240).clamp(
          0,
          scrollable.position.maxScrollExtent,
        ),
      );
      await tester.pump();
    }
    expect(scrollable.position.extentAfter, 0);
  }

  for (final retro in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          testWidgets(
            'Insights retro=$retro dark=$dark width=$width scale=$scale',
            (tester) async {
              AppColors.isRetro = retro;
              AppColors.isDark = dark;
              await tester.binding.setSurfaceSize(Size(width, 900));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final semantics = tester.ensureSemantics();
              try {
                await mount(tester, scale);
                final routine = find.widgetWithText(
                  TextButton,
                  'Routine & Focus',
                );
                final wallet = find.widgetWithText(
                  TextButton,
                  'Wallet & Finance',
                );
                for (final button in [routine, wallet]) {
                  expect(
                    tester.getSize(button).height,
                    greaterThanOrEqualTo(48),
                  );
                  expect(
                    tester.getSize(button).width,
                    greaterThanOrEqualTo(48),
                  );
                }
                expect(
                  tester
                      .getSemantics(find.bySemanticsLabel('Routine & Focus'))
                      .hasFlag(SemanticsFlag.isSelected),
                  isTrue,
                );
                expect(find.byType(FittedBox), findsNothing);
                await tester.tap(find.text('Review History'));
                await tester.pumpAndSettle();
                expect(find.byType(ReviewHistoryScreen), findsOneWidget);
                expect(tester.takeException(), isNull);
                await scrollEntireView(tester);
                Navigator.of(
                  tester.element(find.byType(ReviewHistoryScreen)),
                ).pop();
                await tester.pumpAndSettle();
                await scrollEntireView(tester);
                expect(find.text('CONSISTENCY (LAST 35 DAYS)'), findsOneWidget);
                // Selecting a heatmap day also exercises the wrapping preview.
                final cells = find.byWidgetPredicate(
                  (widget) =>
                      widget is AnimatedContainer &&
                      widget.constraints?.maxWidth == 24 &&
                      widget.constraints?.maxHeight == 24,
                );
                await tester.ensureVisible(cells.last);
                await tester.tap(cells.last);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await tester.tap(wallet);
                await tester.pumpAndSettle();
                expect(
                  tester
                      .getSemantics(find.bySemanticsLabel('Wallet & Finance'))
                      .hasFlag(SemanticsFlag.isSelected),
                  isTrue,
                );
                expect(find.byType(FittedBox), findsNothing);
                await scrollEntireView(tester);
                expect(find.text('BUDGET DISCIPLINE RATE'), findsOneWidget);
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }

  testWidgets(
    'reduced motion stops the active streak pulse after a preference change',
    (tester) async {
      await mount(tester, 1, reducedMotion: false);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await mount(tester, 1);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
