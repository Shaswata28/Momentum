import 'package:hive_flutter/hive_flutter.dart';
import '../models/enums.dart';
import '../models/routine_period.dart';
import '../models/routine_task.dart';
import '../models/daily_task_instance.dart';
import '../models/eod_log.dart';
import '../models/time_of_day_adapter.dart';
import '../models/transaction.dart';
import '../models/month_summary.dart';
import '../models/wallet_settings.dart';
import '../models/user_settings.dart';
import '../models/simple_goal.dart';
import '../models/fixed_expense.dart';

/// Initializes Hive, registers all type adapters uniquely,
/// and opens all required boxes for the app to function offline.
Future<void> initHive() async {
  await Hive.initFlutter();

  // Register Custom Adapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TimeOfDayAdapter());
    Hive.registerAdapter(TaskTypeAdapter());
    Hive.registerAdapter(TaskStatusAdapter());
    Hive.registerAdapter(RoutinePeriodAdapter());
    Hive.registerAdapter(RoutineTaskAdapter());
    Hive.registerAdapter(DailyTaskInstanceAdapter());
    Hive.registerAdapter(EODLogAdapter());
    
    // Wallet Phase 4.5 Adapters
    Hive.registerAdapter(DirectionAdapter());
    Hive.registerAdapter(ExpenseTypeAdapter());
    Hive.registerAdapter(IncomeSourceAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(MonthSummaryAdapter());
    Hive.registerAdapter(WalletSettingsAdapter());
    Hive.registerAdapter(UserSettingsAdapter());
    Hive.registerAdapter(SimpleGoalAdapter());
    Hive.registerAdapter(FixedExpenseAdapter());
  }

  // Open boxes
  await Future.wait([
    Hive.openBox<RoutinePeriod>('routinePeriods'),
    Hive.openBox<RoutineTask>('routineTasks'),
    Hive.openBox<DailyTaskInstance>('dailyTaskInstances'),
    Hive.openBox<EODLog>('eodLogs'),
    Hive.openBox<Transaction>('transactions'),
    Hive.openBox<MonthSummary>('monthSummaries'),
    Hive.openBox<WalletSettings>('walletSettings'),
    Hive.openBox<UserSettings>('userSettings'),
    Hive.openBox<SimpleGoal>('simple_goals'),
    Hive.openBox<FixedExpense>('fixedExpenses'),
  ]);

  // Bootstrap default active period if none exists
  final periodBox = Hive.box<RoutinePeriod>('routinePeriods');
  if (periodBox.isEmpty) {
    await periodBox.put(
      'default_period',
      RoutinePeriod(
        id: 'default_period',
        label: 'Semester',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 120)),
        isActive: true,
      ),
    );
  }
}
