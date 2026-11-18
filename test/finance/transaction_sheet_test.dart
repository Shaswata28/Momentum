import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:momentum/models/transaction.dart';
import 'package:momentum/providers/wallet_providers.dart';
import 'package:momentum/repositories/wallet_repository.dart';
import 'package:momentum/screens/wallet/transaction_sheet.dart';

class _DelayedRepository extends WalletRepository {
  final List<Transaction> writes = [];
  Completer<void>? pending;
  bool fail = false;

  @override
  Future<void> saveTransaction(Transaction tx) async {
    writes.add(tx);
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Storage unavailable');
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> showSheet(
    WidgetTester tester,
    _DelayedRepository repo, {
    String? visibleMonth,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TransactionSheet(
                    initialIsIncome: false,
                    visibleMonthId: visibleMonth,
                  ),
                ),
                child: const Text('Add transaction'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Save Transaction');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets(
    'defaults to today rather than browsing month and blocks duplicate save',
    (tester) async {
      final repo = _DelayedRepository()..pending = Completer<void>();
      await showSheet(tester, repo, visibleMonth: '2020-01');
      expect(
        find.textContaining('outside the month you are viewing'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, '15.25');
      await save(tester);
      expect(find.text('Saving...'), findsOneWidget);
      await tester.tap(find.text('Saving...'));
      await tester.pump();
      expect(repo.writes, hasLength(1));
      final tx = repo.writes.single;
      final today = DateTime.now();
      expect(tx.date, DateUtils.dateOnly(today));
      expect(tx.monthId, WalletRepository.monthIdForDate(today));
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TransactionSheet), findsNothing);
      expect(find.textContaining('Recorded '), findsOneWidget);
    },
  );

  testWidgets('backdated picker writes chosen date-derived month', (
    tester,
  ) async {
    final repo = _DelayedRepository();
    await showSheet(tester, repo);
    final backdate = DateTime(DateTime.now().year - 1, 12, 31);
    await tester.tap(find.textContaining('Transaction date:'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.lastDate, DateUtils.dateOnly(DateTime.now()));
    picker.onDateChanged(backdate);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '20');
    await save(tester);
    await tester.pumpAndSettle();
    expect(repo.writes.single.date, backdate);
    expect(
      repo.writes.single.monthId,
      WalletRepository.monthIdForDate(backdate),
    );
  });

  testWidgets('storage failure keeps inputs and allows retry', (tester) async {
    final repo = _DelayedRepository()..fail = true;
    await showSheet(tester, repo);
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.enterText(find.byType(TextField).last, 'Bus home');
    await save(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save.'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Bus home'), findsOneWidget);
    repo.fail = false;
    await save(tester);
    await tester.pumpAndSettle();
    expect(repo.writes, hasLength(2));
    expect(repo.writes[0].id, repo.writes[1].id);
    expect(find.byType(TransactionSheet), findsNothing);
  });

  testWidgets('invalid finite-positive amount never reaches storage', (
    tester,
  ) async {
    final repo = _DelayedRepository();
    await showSheet(tester, repo);
    for (final amount in ['NaN', 'Infinity', '0', '-5']) {
      await tester.enterText(find.byType(TextField).first, amount);
      await save(tester);
    }
    expect(repo.writes, isEmpty);
  });
}
