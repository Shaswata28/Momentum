import 'package:flutter_dnd/flutter_dnd.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import 'focus_blocker_service.dart';
import 'dart:async';

class DndService {
  static final DndService _instance = DndService._internal();
  factory DndService() => _instance;
  DndService._internal();

  Timer? _checkTimer;
  List<DailyTaskInstance> _todayTasks = [];
  bool _isDndActive = false;
  int _previousFilter = FlutterDnd.INTERRUPTION_FILTER_ALL;
  Future<void> _syncQueue = Future.value();

  Future<void> updateTasks(List<DailyTaskInstance> tasks) {
    _todayTasks = tasks;
    return _syncState();
  }

  Future<void> init() async {
    // Only check DND permission if user has already completed onboarding.
    // During onboarding this is called explicitly from the permissions page.
  }

  Future<void> requestDndPermissionIfNeeded() async {
    bool? isGranted = await FlutterDnd.isNotificationPolicyAccessGranted;
    if (isGranted != null && !isGranted) {
      FlutterDnd.gotoPolicySettings();
    }
  }

  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncState(),
    );
  }

  Future<void> _syncState() {
    _syncQueue = _syncQueue.then((_) async {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
      try {
        final preferences = Hive.box('appSettings');
        final previous = preferences.get('focus.previousDndFilter');
        if (!_isDndActive && previous is int) {
          _isDndActive = true;
          _previousFilter = previous;
        }
        final now = DateTime.now();
        bool shouldBeOn = false;
        for (var task in _todayTasks) {
          if (!task.enableDND ||
              (task.status != TaskStatus.pending &&
                  task.status != TaskStatus.inProgress) ||
              task.date.year != now.year ||
              task.date.month != now.month ||
              task.date.day != now.day) {
            continue;
          }
          if (task.status == TaskStatus.inProgress) {
            shouldBeOn = true;
            break;
          }
          if (task.scheduledTime != null) {
            final start = DateTime(
              now.year,
              now.month,
              now.day,
              task.scheduledTime!.hour,
              task.scheduledTime!.minute,
            );
            final end = start.add(Duration(minutes: task.durationMinutes));
            if (now.isAfter(start) && now.isBefore(end)) {
              shouldBeOn = true;
              break;
            }
          } else if (task.flexWindowStart != null &&
              task.flexWindowEnd != null) {
            final start = DateTime(
              now.year,
              now.month,
              now.day,
              task.flexWindowStart!.hour,
              task.flexWindowStart!.minute,
            );
            final end = DateTime(
              now.year,
              now.month,
              now.day,
              task.flexWindowEnd!.hour,
              task.flexWindowEnd!.minute,
            );
            if (now.isAfter(start) && now.isBefore(end)) {
              shouldBeOn = true;
              break;
            }
          }
        }
        if (await FlutterDnd.isNotificationPolicyAccessGranted != true) {
          _isDndActive = false;
          await FocusBlockerService().syncTasks(_todayTasks);
          return;
        }
        if (shouldBeOn && !_isDndActive) {
          _previousFilter =
              await FlutterDnd.getCurrentInterruptionFilter() ??
              FlutterDnd.INTERRUPTION_FILTER_ALL;
          if (_previousFilter == FlutterDnd.INTERRUPTION_FILTER_UNKNOWN)
            _previousFilter = FlutterDnd.INTERRUPTION_FILTER_ALL;
          await preferences.put('focus.previousDndFilter', _previousFilter);
          _isDndActive =
              await FlutterDnd.setInterruptionFilter(
                FlutterDnd.INTERRUPTION_FILTER_NONE,
              ) ==
              true;
          if (!_isDndActive)
            await preferences.delete('focus.previousDndFilter');
        } else if (!shouldBeOn && _isDndActive) {
          if (await FlutterDnd.setInterruptionFilter(_previousFilter) == true) {
            _isDndActive = false;
            await preferences.delete('focus.previousDndFilter');
          }
        }
        await FocusBlockerService().syncTasks(_todayTasks);
      } on PlatformException catch (error) {
        debugPrint('DND unavailable: ${error.code}');
      } on MissingPluginException {
        // Native focus integrations are optional on unsupported platforms.
      }
    });
    return _syncQueue;
  }
}
