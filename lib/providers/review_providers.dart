import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/eod_log.dart';
import '../repositories/eod_log_repository.dart';

final eodRepoProvider = Provider((ref) => EODLogRepository());
final reviewHistoryProvider = StreamProvider<List<EODLog>>(
  (ref) => ref.watch(eodRepoProvider).watchLogs(),
);

// Re-evaluate local-date derived UI while the app remains open as well as on resume.
final localTimeProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
final todayReviewProvider = Provider<EODLog?>((ref) {
  final now = ref.watch(localTimeProvider).valueOrNull ?? DateTime.now();
  final logs =
      ref.watch(reviewHistoryProvider).valueOrNull ??
      ref.watch(eodRepoProvider).getAllLogs();
  return logs
      .where(
        (log) =>
            log.date.year == now.year &&
            log.date.month == now.month &&
            log.date.day == now.day,
      )
      .firstOrNull;
});
