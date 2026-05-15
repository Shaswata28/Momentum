import 'package:hive/hive.dart';
import '../models/routine_period.dart';

/// Repository handling CRUD operations for [RoutinePeriod] securely offline.
class RoutinePeriodRepository {
  final Box<RoutinePeriod> _box = Hive.box<RoutinePeriod>('routinePeriods');

  /// Fetches all routine periods.
  List<RoutinePeriod> getAll() {
    return _box.values.toList();
  }

  /// Retrieves the currently active routine period.
  RoutinePeriod? getActivePeriod() {
    try {
      return _box.values.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Saves or updates a routine period.
  Future<void> save(RoutinePeriod period) async {
    await _box.put(period.id, period);
  }

  /// Deletes a routine period securely.
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
