import 'package:flutter_dnd/flutter_dnd.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import 'dart:async';

class DndService {
  static final DndService _instance = DndService._internal();
  factory DndService() => _instance;
  DndService._internal();

  Timer? _checkTimer;
  List<DailyTaskInstance> _todayTasks = [];
  bool _isDndActive = false;

  void updateTasks(List<DailyTaskInstance> tasks) {
    _todayTasks = tasks;
  }

  Future<void> init() async {
    bool? isGranted = await FlutterDnd.isNotificationPolicyAccessGranted;
    if (isGranted != null && !isGranted) {
      FlutterDnd.gotoPolicySettings();
    }
  }

  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
       final now = DateTime.now();
       bool shouldBeOn = false;
       for (var task in _todayTasks) {
          if (task.status == TaskStatus.done || !task.enableDND) continue;
          if (task.scheduledTime != null) {
              final start = DateTime(now.year, now.month, now.day, task.scheduledTime!.hour, task.scheduledTime!.minute);
              final end = start.add(Duration(minutes: task.durationMinutes));
              if (now.isAfter(start) && now.isBefore(end)) {
                 shouldBeOn = true;
                 break;
              }
          } else if (task.flexWindowStart != null && task.flexWindowEnd != null) {
              final start = DateTime(now.year, now.month, now.day, task.flexWindowStart!.hour, task.flexWindowStart!.minute);
              final end = DateTime(now.year, now.month, now.day, task.flexWindowEnd!.hour, task.flexWindowEnd!.minute);
              if (now.isAfter(start) && now.isBefore(end)) {
                 shouldBeOn = true;
                 break;
              }
          }
       }
       
       if (shouldBeOn && !_isDndActive) {
           await FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_NONE);
           _isDndActive = true;
       } else if (!shouldBeOn && _isDndActive) {
           await FlutterDnd.setInterruptionFilter(FlutterDnd.INTERRUPTION_FILTER_ALL);
           _isDndActive = false;
       }
    });
  }
}
