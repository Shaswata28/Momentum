import 'package:hive/hive.dart';
import '../models/eod_log.dart';

/// Repository overseeing historical storage of [EODLog] nightly records.
class EODLogRepository {
  final Box<EODLog> _box = Hive.box<EODLog>('eodLogs');
  static final Set<String> _savingDates = {};

  EODLog? getForDate(DateTime date) => getAllLogs()
      .where(
        (log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day,
      )
      .firstOrNull;

  Stream<List<EODLog>> watchLogs() async* {
    yield getAllLogs();
    yield* _box.watch().map((_) => getAllLogs());
  }

  /// Acquires sorted sequential history.
  List<EODLog> getAllLogs() {
    var logs = _box.values.toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  /// Returns all logs for the given [year] and [month], sorted ascending by date.
  List<EODLog> getLogsForMonth(int year, int month) {
    final logs = _box.values
        .where((log) => log.date.year == year && log.date.month == month)
        .toList();
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  /// Flushes current log persistently offline.
  Future<void> save(EODLog log) async {
    final dateKey = '${log.date.year}-${log.date.month}-${log.date.day}';
    if (!_savingDates.add(dateKey))
      throw StateError('A review is already being saved.');
    try {
      if (getForDate(log.date) != null || _box.containsKey(log.id)) {
        throw StateError('A review already exists for this date.');
      }
      await _box.put(log.id, log);
    } finally {
      _savingDates.remove(dateKey);
    }
  }
}
