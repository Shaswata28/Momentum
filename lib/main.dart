import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/main_layout.dart';
import 'repositories/hive_init.dart';
import 'services/notification_service.dart';
import 'services/dnd_service.dart';
import 'package:home_widget/home_widget.dart';
import 'repositories/daily_task_instance_repository.dart';
import 'services/widget_service.dart';
import 'services/month_rollover_service.dart';
import 'models/enums.dart';
import 'models/daily_task_instance.dart';
import 'models/user_settings.dart';
import 'screens/onboarding/onboarding_screen.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;
  final host = uri.host;
  final taskId = uri.queryParameters['taskId'];
  if (taskId == null) return;

  if (host == 'done' || host == 'skip') {
    await initHive();
    final repo = DailyTaskInstanceRepository();
    final tasks = repo.getTasksForDate(DateTime.now());
    var task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      final updatedTask = DailyTaskInstance(
        id: task.id,
        routineTaskId: task.routineTaskId,
        date: task.date,
        title: task.title,
        taskType: task.taskType,
        scheduledTime: task.scheduledTime,
        flexWindowStart: task.flexWindowStart,
        flexWindowEnd: task.flexWindowEnd,
        durationMinutes: task.durationMinutes,
        status: host == 'done' ? TaskStatus.done : TaskStatus.skipped,
        completedAt: DateTime.now(),
        rescheduledToDate: task.rescheduledToDate,
        isBufferBlock: task.isBufferBlock,
        enableDND: task.enableDND,
        notificationId: task.notificationId,
      );
      await repo.save(updatedTask);

      if (host == 'done') {
        await NotificationService().cancelTaskNotifications(taskId);
      }

      final updatedTasks = repo.getTasksForDate(DateTime.now());
      await WidgetService.syncWidgetState(updatedTasks);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  await MonthRolloverService().checkAndRollover();

  final ns = NotificationService();
  await ns.init();
  await ns.requestPermissions();
  await ns.scheduleEODPrompt();

  final dnd = DndService();
  await dnd.init();
  dnd.startMonitoring();

  await HomeWidget.registerInteractivityCallback(backgroundCallback);
  runApp(const ProviderScope(child: DailyTrackerApp()));
}

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box<UserSettings>('userSettings');
    final settings = settingsBox.get('user');
    final isFirstLaunch = settings == null || settings.isFirstLaunch;

    return MaterialApp(
      title: 'Momentum',
      theme: AppTheme.darkTheme,
      home: isFirstLaunch ? const OnboardingScreen() : const MainLayout(),
      debugShowCheckedModeBanner: false,
    );
  }
}
