import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import '../repositories/hive_init.dart';
import 'native_task_action_service.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  final taskId = notificationResponse.payload;
  final actionId = notificationResponse.actionId;

  if (taskId != null && actionId != null) {
    if (actionId == 'mark_done' ||
        actionId == 'skip' ||
        actionId == 'start_now') {
      await initHive();
      await NativeTaskActionService.apply(
        taskId,
        actionId == 'mark_done'
            ? TaskStatus.done
            : actionId == 'skip'
            ? TaskStatus.skipped
            : TaskStatus.inProgress,
      );
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static VoidCallback? onForegroundAction;

  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    await refreshLocalTimezone();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        await notificationTapBackground(response);
        onForegroundAction?.call();
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const AndroidNotificationChannel liveChannel = AndroidNotificationChannel(
      'live_task_channel_v2',
      'Live Task Activity',
      description: 'Ongoing progress and countdown for active routine tasks',
      importance: Importance.defaultImportance,
      showBadge: true,
      enableVibration: false,
      playSound: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(liveChannel);
  }

  static const int liveNotificationId = 888888;

  Future<bool> refreshLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
      return true;
    } on PlatformException {
      // Unsupported platforms cannot provide device timezone information.
    } on MissingPluginException {
      // Keep the timezone library's default on unsupported platforms.
    } on tz.LocationNotFoundException {
      // Do not schedule a local reminder using an unrecognized device zone.
    } on ArgumentError {
      // Some platforms cannot supply a valid IANA timezone identifier.
    }
    return false;
  }

  Future<bool?> notificationsEnabled() async {
    try {
      return await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> showLiveTaskNotification({
    required String taskId,
    required String title,
    required int progressPercent,
    required int remainingMinutes,
    required String endTimeFormatted,
    String? taskType,
  }) async {
    final timeSummary = remainingMinutes > 0
        ? '$remainingMinutes min${remainingMinutes == 1 ? '' : 's'} left · Ends at $endTimeFormatted'
        : 'Time is up · Ended at $endTimeFormatted';

    final bigTextLines = [
      '⏱ $remainingMinutes min${remainingMinutes == 1 ? '' : 's'} remaining (Ends at $endTimeFormatted)',
      '📊 $progressPercent% elapsed',
      if (taskType != null && taskType.isNotEmpty) '🏷️ $taskType',
      '💡 Focus on one task at a time.',
    ].join('\n');

    final bigTextStyleInformation = BigTextStyleInformation(
      bigTextLines,
      contentTitle: title,
      summaryText: '$progressPercent% • Live Activity',
      htmlFormatBigText: false,
      htmlFormatContentTitle: false,
      htmlFormatSummaryText: false,
    );

    final androidDetails = AndroidNotificationDetails(
      'live_task_channel_v2',
      'Live Task Activity',
      channelDescription:
          'Ongoing progress and countdown for active routine tasks',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progressPercent,
      subText: '$progressPercent%',
      category: AndroidNotificationCategory.progress,
      styleInformation: bigTextStyleInformation,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'mark_done',
          '✓ Complete',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'skip',
          'Skip',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
    );

    await flutterLocalNotificationsPlugin.show(
      liveNotificationId,
      title,
      timeSummary,
      NotificationDetails(android: androidDetails),
      payload: taskId,
    );
  }

  Future<void> cancelLiveTaskNotification() async {
    await flutterLocalNotificationsPlugin.cancel(liveNotificationId);
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  int _generateBaseId(String id) {
    return id.hashCode.abs() % 100000000;
  }

  Future<void> scheduleTaskNotifications(DailyTaskInstance task) async {
    if (task.status == TaskStatus.done ||
        task.status == TaskStatus.skipped ||
        task.status == TaskStatus.rescheduled ||
        task.isBufferBlock)
      return;

    final baseId = _generateBaseId(task.id);
    final now = DateTime.now();
    if (await notificationsEnabled() != true) return;
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exactAllowed =
        await android?.canScheduleExactNotifications() ?? false;
    final scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'daily_routine_channel',
          'Routine Notifications',
          channelDescription: 'Reminders for daily routine tasks',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('start_now', 'Start Now'),
            AndroidNotificationAction('mark_done', 'Mark Done'),
            AndroidNotificationAction('skip', 'Skip'),
          ],
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    if ((task.taskType == TaskType.fixed || task.taskType == TaskType.adhoc) &&
        task.scheduledTime != null) {
      final taskTime = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.scheduledTime!.hour,
        task.scheduledTime!.minute,
      );

      final beforeTime = taskTime.subtract(const Duration(minutes: 10));
      if (beforeTime.isAfter(now)) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          baseId,
          'Upcoming Task',
          '${task.title} starts in 10 minutes.',
          tz.TZDateTime.from(beforeTime, tz.local),
          platformChannelSpecifics,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      }

      if (taskTime.isAfter(now)) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          baseId + 1,
          'Task Started',
          'Time for ${task.title}',
          tz.TZDateTime.from(taskTime, tz.local),
          platformChannelSpecifics,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      }
    } else if ((task.taskType == TaskType.floating ||
            task.taskType == TaskType.adhoc) &&
        task.flexWindowStart != null &&
        task.flexWindowEnd != null) {
      final startTime = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.flexWindowStart!.hour,
        task.flexWindowStart!.minute,
      );
      final endTime = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.flexWindowEnd!.hour,
        task.flexWindowEnd!.minute,
      );

      if (startTime.isAfter(now)) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          baseId,
          'Window Opened',
          'You can now start ${task.title}',
          tz.TZDateTime.from(startTime, tz.local),
          platformChannelSpecifics,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      }

      final warningTime = endTime.subtract(const Duration(minutes: 45));
      if (warningTime.isAfter(now)) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          baseId + 1,
          'Window Closing Soon',
          '${task.title} window closes in 45 minutes.',
          tz.TZDateTime.from(warningTime, tz.local),
          platformChannelSpecifics,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: task.id,
        );
      }
    }
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    final baseId = _generateBaseId(taskId);
    await flutterLocalNotificationsPlugin.cancel(baseId);
    await flutterLocalNotificationsPlugin.cancel(baseId + 1);
  }

  static const eodReminderKey = 'eodReminderMinutes';

  TimeOfDay get savedEODReminder {
    final value = Hive.box('appSettings').get(eodReminderKey);
    final minutes = value is int && value >= 0 && value < 1440
        ? value
        : 22 * 60 + 30;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  Future<bool> saveEODReminder(TimeOfDay time) async {
    await Hive.box(
      'appSettings',
    ).put(eodReminderKey, time.hour * 60 + time.minute);
    return rescheduleEODPrompt(time);
  }

  Future<bool> scheduleEODPrompt() => rescheduleEODPrompt(savedEODReminder);

  Future<bool> rescheduleEODPrompt(TimeOfDay time) async {
    try {
      if (!await refreshLocalTimezone()) {
        await flutterLocalNotificationsPlugin.cancel(999999);
        return false;
      }
      if (await notificationsEnabled() != true) {
        await flutterLocalNotificationsPlugin.cancel(999999);
        return false;
      }
      // Cancel the existing EOD notification first
      await flutterLocalNotificationsPlugin.cancel(999999);

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'eod_channel',
            'EOD Log Prompts',
            channelDescription: 'Reminders to log your End Of Day score',
            importance: Importance.max,
            priority: Priority.high,
          );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!scheduledDate.isAfter(now)) {
        scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + 1,
          time.hour,
          time.minute,
        );
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        999999,
        'End of Day Log',
        'Time to log your daily progress and score!',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
