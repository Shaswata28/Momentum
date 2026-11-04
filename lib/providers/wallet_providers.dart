import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../repositories/wallet_repository.dart';
import '../models/transaction.dart';
import '../models/month_summary.dart';
import '../models/fixed_expense.dart';

final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '৳', decimalDigits: 2);

final walletRepositoryProvider = Provider((ref) => WalletRepository());

/// The currently selected month in the wallet screen. Defaults to current month 1st day.
final selectedMonthDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final selectedMonthIdProvider = Provider<String>((ref) {
  final dt = ref.watch(selectedMonthDateProvider);
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
});

final currentMonthIdProvider = Provider<String>((ref) {
  return ref.watch(selectedMonthIdProvider);
});

final currentMonthSummaryProvider = Provider<MonthSummary?>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  final monthId = ref.watch(currentMonthIdProvider);
  return repo.getMonthSummary(monthId);
});

final currentTransactionsProvider = Provider<List<Transaction>>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  final monthId = ref.watch(currentMonthIdProvider);
  final txs = repo.getTransactionsForMonth(monthId);
  txs.sort((a, b) => b.date.compareTo(a.date));
  return txs;
});

final fixedExpensesProvider = Provider<List<FixedExpense>>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  // Force dependency on transactions so this recomputes on every add/delete (for UI updates)
  ref.watch(currentTransactionsProvider);
  final expenses = repo.getAllFixedExpenses();
  expenses.sort((a, b) => a.billingDay.compareTo(b.billingDay));
  return expenses;
});

final runningBalanceProvider = Provider<double>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  final monthId = ref.watch(currentMonthIdProvider);
  // Force dependency on transactions so this recomputes on every add/delete
  ref.watch(currentTransactionsProvider);
  return repo.computeRunningBalance(monthId);
});

final openingBalanceProvider = Provider<double>((ref) {
  final summary = ref.watch(currentMonthSummaryProvider);
  return summary?.openingBalance ?? 0.0;
});

class MonthlyTotals {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;

  const MonthlyTotals({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
  });
}

final monthlyTotalsProvider = Provider<MonthlyTotals>((ref) {
  final txs = ref.watch(currentTransactionsProvider);
  final repo = ref.watch(walletRepositoryProvider);
  double income = 0;
  double expense = 0;

  for (final t in txs) {
    if (t.isSettled &&
        (t.expenseType == ExpenseType.borrowed || t.expenseType == ExpenseType.lent) &&
        !repo.hasSettledCounterpart(t.id)) {
      continue;
    }
    if (t.direction == Direction.income) {
      income += t.amount;
    } else if (t.direction == Direction.expense) {
      expense += t.amount;
    }
  }

  return MonthlyTotals(
    totalIncome: income,
    totalExpense: expense,
    netSavings: income - expense,
  );
});

final dailySpendingProvider = Provider<Map<int, double>>((ref) {
  final txs = ref.watch(currentTransactionsProvider);
  final map = <int, double>{};
  for (final t in txs) {
    if (t.direction == Direction.expense) {
      map[t.date.day] = (map[t.date.day] ?? 0) + t.amount;
    }
  }
  return map;
});

class WalletNotifier extends StateNotifier<void> {
  final WalletRepository repo;
  final Ref ref;

  WalletNotifier(this.repo, this.ref) : super(null);

  Future<void> addTransaction(Transaction tx) async {
    await repo.saveTransaction(tx);
    ref.invalidate(currentTransactionsProvider);
    ref.invalidate(runningBalanceProvider);
    ref.invalidate(currentMonthSummaryProvider);
  }

  Future<void> deleteTransaction(String id) async {
    await repo.deleteTransaction(id);
    ref.invalidate(currentTransactionsProvider);
    ref.invalidate(runningBalanceProvider);
    ref.invalidate(currentMonthSummaryProvider);
  }

  Future<void> settleTransaction(Transaction iou) async {
    final newId = '${iou.id}_settled';
    await repo.settleTransaction(iou, newId);
    ref.invalidate(currentTransactionsProvider);
    ref.invalidate(runningBalanceProvider);
    ref.invalidate(currentMonthSummaryProvider);
  }

  Future<void> addFixedExpense(FixedExpense expense) async {
    await repo.saveFixedExpense(expense);
    ref.invalidate(fixedExpensesProvider);
  }

  Future<void> deleteFixedExpense(String id) async {
    await repo.deleteFixedExpense(id);
    ref.invalidate(fixedExpensesProvider);
  }
}

final walletNotifierProvider = StateNotifierProvider<WalletNotifier, void>((ref) {
  return WalletNotifier(ref.watch(walletRepositoryProvider), ref);
});
