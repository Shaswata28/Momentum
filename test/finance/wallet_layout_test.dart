import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/fixed_expense.dart';
import 'package:momentum/models/month_summary.dart';
import 'package:momentum/models/transaction.dart';
import 'package:momentum/models/wallet_settings.dart';
import 'package:momentum/screens/wallet/wallet_screen.dart';
import 'package:momentum/screens/wallet/transaction_sheet.dart';
import 'package:momentum/theme/app_colors.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    directory = await Directory.systemTemp.createTemp('wallet_layout_');
    Hive.init(directory.path);
    Hive.registerAdapter(DirectionAdapter());
    Hive.registerAdapter(ExpenseTypeAdapter());
    Hive.registerAdapter(IncomeSourceAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(MonthSummaryAdapter());
    Hive.registerAdapter(FixedExpenseAdapter());
    Hive.registerAdapter(WalletSettingsAdapter());
    await Hive.openBox<Transaction>('transactions');
    await Hive.openBox<MonthSummary>('monthSummaries');
    await Hive.openBox<FixedExpense>('fixedExpenses');
    await Hive.openBox<WalletSettings>('walletSettings');
    await Hive.box<WalletSettings>(
      'walletSettings',
    ).put('settings', WalletSettings(monthlyBudget: 1000, semesterGoal: 10000));
    await Hive.box<FixedExpense>('fixedExpenses').put(
      'bill',
      FixedExpense(
        id: 'bill',
        name: 'Internet and shared utilities with a long bill name',
        amount: 123456789.12,
        billingDay: 31,
      ),
    );
    final now = DateTime.now();
    await Hive.box<Transaction>('transactions').put(
      'tx',
      Transaction(
        id: 'tx',
        date: now,
        direction: Direction.expense,
        amount: 123456789.12,
        note: 'A long transaction note with details',
        monthId: '${now.year}-${now.month.toString().padLeft(2, '0')}',
      ),
    );
  });
  tearDownAll(() async {
    AppColors.isRetro = false;
    AppColors.isDark = true;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final retro in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          testWidgets(
            'Wallet layout retro=$retro dark=$dark width=$width scale=$scale',
            (tester) async {
              AppColors.isRetro = retro;
              AppColors.isDark = dark;
              await tester.binding.setSurfaceSize(Size(width, 900));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              await tester.pumpWidget(
                ProviderScope(
                  child: MaterialApp(
                    theme: ThemeData(
                      brightness: dark ? Brightness.dark : Brightness.light,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const WalletScreen(),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -600),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -600),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  testWidgets('large-text transaction sheet scrolls with keyboard open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: Scaffold(
              body: TransactionSheet(
                initialIsIncome: false,
                startAsBorrowLend: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Transaction'));
    expect(tester.takeException(), isNull);
  });
}
