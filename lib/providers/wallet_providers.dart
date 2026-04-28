import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../repositories/wallet_repository.dart';
import '../models/transaction.dart';
import '../models/month_summary.dart';
import '../models/fixed_expense.dart';

final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '৳', decimalDigits: 2);

final walletRepositoryProvider = Provider((ref) => WalletRepository());

final currentMonthIdProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
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
