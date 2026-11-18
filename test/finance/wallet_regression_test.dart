import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:momentum/models/fixed_expense.dart';
import 'package:momentum/models/month_summary.dart';
import 'package:momentum/models/transaction.dart';
import 'package:momentum/providers/review_providers.dart';
import 'package:momentum/providers/wallet_providers.dart';
import 'package:momentum/repositories/wallet_repository.dart';

void main() {
  late Directory directory;
  late WalletRepository repo;
  late ProviderContainer container;
  final now = DateTime.now();
  final currentMonth = WalletRepository.monthIdForDate(now);
  final historicalDate = DateTime(now.year - 1, 12, 31);
  final historicalMonth = WalletRepository.monthIdForDate(historicalDate);

  Transaction entry(
    String id,
    DateTime date,
    double amount, {
    Direction direction = Direction.expense,
    ExpenseType? type,
    bool settled = false,
  }) => Transaction(
    id: id,
    date: date,
    amount: amount,
    direction: direction,
    expenseType: type,
    isSettled: settled,
    monthId: WalletRepository.monthIdForDate(date),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('momentum_wallet_test_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(DirectionAdapter());
    if (!Hive.isAdapterRegistered(8))
      Hive.registerAdapter(ExpenseTypeAdapter());
    if (!Hive.isAdapterRegistered(9))
      Hive.registerAdapter(IncomeSourceAdapter());
    if (!Hive.isAdapterRegistered(10))
      Hive.registerAdapter(TransactionAdapter());
    if (!Hive.isAdapterRegistered(11))
      Hive.registerAdapter(MonthSummaryAdapter());
    if (!Hive.isAdapterRegistered(15))
      Hive.registerAdapter(FixedExpenseAdapter());
    await Hive.openBox<Transaction>('transactions');
    await Hive.openBox<MonthSummary>('monthSummaries');
    await Hive.openBox<FixedExpense>('fixedExpenses');
    repo = WalletRepository();
    container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(repo),
        localTimeProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'browsing history isolates current-month balance, totals and chart',
    () async {
      await repo.saveMonthSummary(
        MonthSummary(
          id: currentMonth,
          openingBalance: 100,
          totalIncome: 9999,
          totalExpense: 8888,
          closingBalance: 0,
        ),
      );
      await repo.saveTransaction(entry('today', now, 25));
      await repo.saveTransaction(
        entry('past', historicalDate, 60, direction: Direction.income),
      );
      container.read(selectedMonthDateProvider.notifier).state = historicalDate;
      expect(container.read(currentMonthIdProvider), currentMonth);
      expect(container.read(selectedMonthIdProvider), historicalMonth);
      expect(container.read(currentTransactionsProvider).single.id, 'today');
      expect(container.read(selectedTransactionsProvider).single.id, 'past');
      expect(container.read(runningBalanceProvider), 75);
      expect(container.read(monthlyTotalsProvider).netSavings, -25);
      expect(container.read(selectedMonthlyTotalsProvider).netSavings, 60);
      expect(container.read(dailySpendingProvider), {now.day: 25});
    },
  );

  test(
    'new writes reject non-positive/non-finite and mismatched dates',
    () async {
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          repo.saveTransaction(entry('bad', now, amount)),
          throwsArgumentError,
        );
      }
      await expectLater(
        repo.saveTransaction(
          entry(
            'bad-month',
            historicalDate,
            10,
          ).copyWith(monthId: currentMonth),
        ),
        throwsArgumentError,
      );
      await repo.saveTransaction(entry('backdated', historicalDate, 10));
      expect(
        repo.getTransactionsForMonth(historicalMonth).single.date,
        historicalDate,
      );
      expect(repo.getTransactionsForMonth(currentMonth), isEmpty);
    },
  );

  test(
    'settlement retains original month and makes one cash event today',
    () async {
      final iou = entry(
        'borrowed',
        historicalDate,
        80,
        direction: Direction.income,
        type: ExpenseType.borrowed,
      );
      await repo.saveTransaction(iou);
      await Future.wait([
        repo.settleTransaction(iou, 'ignored-one'),
        repo.settleTransaction(iou, 'ignored-two'),
      ]);
      await repo.settleTransaction(iou, 'ignored-three');
      final original = repo.getTransactionsForMonth(historicalMonth).single;
      final repayment = repo.getTransactionsForMonth(currentMonth).single;
      expect(original.date, historicalDate);
      expect(original.isSettled, isTrue);
      expect(repayment.id, 'borrowed_settled');
      expect(repayment.direction, Direction.expense);
      expect(WalletRepository.monthIdForDate(repayment.date), currentMonth);
      expect(repo.computeRunningBalance(historicalMonth), 80);
      expect(repo.computeRunningBalance(currentMonth), -80);
    },
  );

  test(
    'legacy settled IOU remains zero effect without a counterpart',
    () async {
      final legacy = entry(
        'legacy',
        now,
        50,
        type: ExpenseType.lent,
        settled: true,
      );
      await repo.saveTransaction(legacy);
      await repo.settleTransaction(legacy, 'legacy_settled');
      expect(repo.hasSettledCounterpart(legacy.id), isFalse);
      expect(repo.computeRunningBalance(currentMonth), 0);
      expect(container.read(monthlyTotalsProvider).totalExpense, 0);
      expect(container.read(dailySpendingProvider), isEmpty);
    },
  );

  test('existing mismatched historical records are not migrated', () async {
    final legacy = entry(
      'old-mismatch',
      historicalDate,
      12,
    ).copyWith(monthId: currentMonth);
    await Hive.box<Transaction>('transactions').put(legacy.id, legacy);
    expect(
      repo.getTransactionsForMonth(currentMonth).single.date,
      historicalDate,
    );
    expect(repo.getTransactionsForMonth(historicalMonth), isEmpty);
    expect(
      Hive.box<Transaction>('transactions').get(legacy.id)!.monthId,
      currentMonth,
    );
  });

  test(
    'repayment refreshes original and current month without changing browsing',
    () async {
      final iou = entry('lent', historicalDate, 40, type: ExpenseType.lent);
      await repo.saveTransaction(iou);
      container.read(selectedMonthDateProvider.notifier).state = historicalDate;
      expect(container.read(selectedMonthlyTotalsProvider).totalExpense, 40);
      expect(container.read(monthlyTotalsProvider).totalIncome, 0);
      await container
          .read(walletNotifierProvider.notifier)
          .settleTransaction(iou);
      expect(
        container.read(selectedTransactionsProvider).single.isSettled,
        isTrue,
      );
      expect(container.read(monthlyTotalsProvider).totalIncome, 40);
      expect(container.read(selectedMonthIdProvider), historicalMonth);
    },
  );

  test('bill payment retries are idempotent and date-derived', () async {
    final bill = FixedExpense(
      id: 'rent',
      name: 'Rent',
      amount: 75,
      billingDay: 1,
    );
    await repo.saveFixedExpense(bill);
    await Future.wait([repo.payFixedExpense(bill), repo.payFixedExpense(bill)]);
    await repo.payFixedExpense(bill);
    expect(repo.getTransactionsForMonth(currentMonth), hasLength(1));
    expect(repo.computeRunningBalance(currentMonth), -75);
    expect(repo.getAllFixedExpenses().single.lastPaidMonthKey, currentMonth);
  });

  test(
    'current month follows clock across year rollover, selected month stays put',
    () async {
      container.dispose();
      final clock = StreamController<DateTime>();
      container = ProviderContainer(
        overrides: [localTimeProvider.overrideWith((ref) => clock.stream)],
      );
      final subscription = container.listen(currentMonthIdProvider, (_, _) {});
      container.read(selectedMonthDateProvider.notifier).state = DateTime(
        2024,
        6,
      );
      clock.add(DateTime(2026, 12, 31, 23, 59));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentMonthIdProvider), '2026-12');
      clock.add(DateTime(2027, 1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentMonthIdProvider), '2027-01');
      expect(container.read(selectedMonthIdProvider), '2024-06');
      subscription.close();
      await clock.close();
    },
  );
}
