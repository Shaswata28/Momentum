import 'package:hive/hive.dart';
import '../models/eod_log.dart';

/// Repository overseeing historical storage of [EODLog] nightly records.
class EODLogRepository {
  final Box<EODLog> _box = Hive.box<EODLog>('eodLogs');

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
    await _box.put(log.id, log);
  }
}
