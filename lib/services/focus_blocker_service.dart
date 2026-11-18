import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/blocked_app_info.dart';
import '../models/daily_task_instance.dart';
import '../models/enums.dart';
import '../screens/focus/mindful_friction_screen.dart';

class FocusBlockerService {
  static final FocusBlockerService _instance = FocusBlockerService._internal();
  factory FocusBlockerService() => _instance;
  FocusBlockerService._internal();

  static const MethodChannel _channel = MethodChannel(
    'app.momentum.tracker/focus_blocker',
  );
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _boxName = 'focusShieldSettings';
  static const String _keyBlockedPackages = 'blocked_packages';
  static const String _keyPassDate = 'emergency_pass_date';
  static const String _keyPassesUsed = 'emergency_passes_used';
  static const String _keyShieldEnabled = 'shield_enabled';

  List<BlockedAppInfo>? _cachedInstalledApps;
  bool _isFrictionScreenVisible = false;

  Box get _box => Hive.box(_boxName);

  Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMindfulFriction') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _handleIncomingFriction(data);
      }
    });

    // Sync saved blocked apps to native SharedPreferences on startup
    await _syncBlockedAppsToNative();

    // Check if cold-started by a friction intent
    try {
      final pending = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'checkPendingFriction',
      );
      if (pending != null) {
        _handleIncomingFriction(Map<String, dynamic>.from(pending));
      }
    } catch (_) {}
  }

  void _handleIncomingFriction(Map<String, dynamic> data) {
    if (_isFrictionScreenVisible) return;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      // Retry in 500ms if navigation state is not ready yet
      Timer(
        const Duration(milliseconds: 500),
        () => _handleIncomingFriction(data),
      );
      return;
    }

    _isFrictionScreenVisible = true;
    final packageName = data['packageName'] as String? ?? '';
    final appName = data['appName'] as String? ?? packageName;
    final taskName = data['taskName'] as String? ?? 'Focus Task';
    final taskEndTimeMs = data['taskEndTime'] as int? ?? 0;
    final taskEndTime = taskEndTimeMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(taskEndTimeMs)
        : null;

    nav
        .push(
          MaterialPageRoute(
            builder: (_) => MindfulFrictionScreen(
              packageName: packageName,
              appName: appName,
              taskName: taskName,
              taskEndTime: taskEndTime,
            ),
          ),
        )
        .then((_) {
          _isFrictionScreenVisible = false;
        });
  }

  bool isShieldEnabled() {
    return _box.get(_keyShieldEnabled, defaultValue: true) as bool;
  }

  Future<void> setShieldEnabled(bool enabled) async {
    await _box.put(_keyShieldEnabled, enabled);
    if (!enabled) {
      await syncFocusState(isActive: false);
    }
  }

  Future<bool> isAccessibilityGranted() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAccessibilityGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  List<String> getBlockedPackages() {
    final list = _box.get(_keyBlockedPackages, defaultValue: <String>[]);
    return List<String>.from(list as List);
  }

  Future<void> _syncBlockedAppsToNative() async {
    try {
      final packages = getBlockedPackages();
      await _channel.invokeMethod('updateBlockedApps', {'packages': packages});
    } catch (_) {}
  }

  Future<void> toggleAppBlocked(String packageName, bool isBlocked) async {
    final list = getBlockedPackages().toSet();
    if (isBlocked) {
      list.add(packageName);
    } else {
      list.remove(packageName);
    }
    await _box.put(_keyBlockedPackages, list.toList());
    await _syncBlockedAppsToNative();

    // Update in-memory cache
    if (_cachedInstalledApps != null) {
      _cachedInstalledApps = _cachedInstalledApps!.map((app) {
        if (app.packageName == packageName) {
          return app.copyWith(isBlocked: isBlocked);
        }
        return app;
      }).toList();
    }
  }

  Future<void> batchSetBlocked(
    List<String> packageNames,
    bool isBlocked,
  ) async {
    final set = getBlockedPackages().toSet();
    if (isBlocked) {
      set.addAll(packageNames);
    } else {
      set.removeAll(packageNames);
    }
    await _box.put(_keyBlockedPackages, set.toList());
    await _syncBlockedAppsToNative();

    if (_cachedInstalledApps != null) {
      final targetSet = packageNames.toSet();
      _cachedInstalledApps = _cachedInstalledApps!.map((app) {
        if (targetSet.contains(app.packageName)) {
          return app.copyWith(isBlocked: isBlocked);
        }
        return app;
      }).toList();
    }
  }

  Future<List<BlockedAppInfo>> getInstalledApps({bool refresh = false}) async {
    if (_cachedInstalledApps != null && !refresh) {
      return _cachedInstalledApps!;
    }

    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
      );
      if (rawList == null) return [];

      final blockedSet = getBlockedPackages().toSet();
      final apps = rawList.map((item) {
        final map = Map<dynamic, dynamic>.from(item as Map);
        final pkg = map['packageName'] as String? ?? '';
        return BlockedAppInfo.fromMap(map, isBlocked: blockedSet.contains(pkg));
      }).toList();

      _cachedInstalledApps = apps;
      return apps;
    } catch (_) {
      return _cachedInstalledApps ?? [];
    }
  }

  // --- Focus Synchronization ---

  Future<void> syncFocusState({
    required bool isActive,
    String? taskName,
    DateTime? endTime,
  }) async {
    if (!isShieldEnabled()) {
      isActive = false;
    }

    try {
      await _channel.invokeMethod('setFocusState', {
        'isActive': isActive,
        'taskName': taskName ?? 'Focus Task',
        'endTimeMs': endTime?.millisecondsSinceEpoch ?? 0,
      });
    } catch (_) {}
  }

  Future<void> syncTasks(List<DailyTaskInstance> tasks) async {
    if (!isShieldEnabled()) {
      await syncFocusState(isActive: false);
      return;
    }

    final now = DateTime.now();
    bool shouldBeOn = false;
    String activeTitle = 'Focus Task';
    DateTime? activeEndTime;

    for (var task in tasks) {
      if (!task.enableDND ||
          (task.status != TaskStatus.pending &&
              task.status != TaskStatus.inProgress) ||
          task.date.year != now.year ||
          task.date.month != now.month ||
          task.date.day != now.day) {
        continue;
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
          activeTitle = task.title;
          activeEndTime = end;
          break;
        }
      } else if (task.flexWindowStart != null && task.flexWindowEnd != null) {
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
          activeTitle = task.title;
          activeEndTime = end;
          break;
        }
      }
    }

    await syncFocusState(
      isActive: shouldBeOn,
      taskName: activeTitle,
      endTime: activeEndTime,
    );
  }

  // --- Emergency Passes ---

  int getRemainingEmergencyPasses() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final savedDate = _box.get(_keyPassDate, defaultValue: '') as String;

    if (savedDate != todayStr) {
      _box.put(_keyPassDate, todayStr);
      _box.put(_keyPassesUsed, 0);
      return 2;
    }

    final used = _box.get(_keyPassesUsed, defaultValue: 0) as int;
    final remaining = 2 - used;
    return remaining < 0 ? 0 : remaining;
  }

  Future<bool> useEmergencyPass({
    required String targetPackage,
    int minutes = 5,
  }) async {
    final remaining = getRemainingEmergencyPasses();
    if (remaining <= 0) return false;

    final used = _box.get(_keyPassesUsed, defaultValue: 0) as int;
    await _box.put(_keyPassesUsed, used + 1);

    try {
      await _channel.invokeMethod('useEmergencyPass', {
        'minutes': minutes,
        'targetPackage': targetPackage,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
