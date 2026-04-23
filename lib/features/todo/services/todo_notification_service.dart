import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/todo_model.dart';
import 'todo_db_helper.dart';

class TodoNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  static const String _channelId = 'todo_channel_v2';
  static const String _channelName = 'SmartDesk Task Reminders';
  static const String _channelDescription = 'Notifications for tasks and reminders';

  /// Schedules this many days of recurring notifications ahead on each app open.
  static const int _scheduleWindowDays = 30;

  /// Maximum individual alarm slots per task (per slot index in ID scheme).
  static const int _maxSlotsPerTask = 60;

  TodoNotificationService(this._notificationsPlugin);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // ---------------------------------------------------------------------------
  // Reschedule all (called on app open)
  // ---------------------------------------------------------------------------

  Future<void> rescheduleAllTasks() async {
    final dbHelper = TodoDatabaseHelper.instance;

    final recurringTasks = await dbHelper.getRecurringTasks();
    for (final task in recurringTasks) {
      if (task.isActive && task.isNotificationEnabled) {
        await scheduleRecurringTask(task);
      } else {
        // Make sure disabled/inactive tasks are fully cancelled
        await cancelRecurringTask(task);
      }
    }

    final oneTimeTasks = await dbHelper.getOneTimeTasks();
    for (final task in oneTimeTasks) {
      if (!task.isCompleted && task.isNotificationEnabled) {
        await scheduleOneTimeTask(task);
      } else {
        await cancelOneTimeTask(task);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Recurring Task Scheduling
  // ---------------------------------------------------------------------------

  Future<void> scheduleRecurringTask(RecurringTask task) async {
    // Always cancel first so stale alarms are removed
    await cancelRecurringTask(task);

    if (!task.isNotificationEnabled || task.notificationTime == null || !task.isActive) {
      return;
    }

    final timeParts = task.notificationTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    final now = DateTime.now();
    final windowEnd = now.add(const Duration(days: _scheduleWindowDays));

    // Build a flat list of all DateTime occurrences in the window
    final List<DateTime> occurrences = [];

    if (task.repeatType == 0) {
      // Every working day: Mon (1) – Sat (6)
      occurrences.addAll(_getWeekdayOccurrences({1, 2, 3, 4, 5, 6}, hour, minute, now, windowEnd, task));
    } else if (task.repeatType == 1) {
      // Specific days
      if (task.repeatDays != null && task.repeatDays!.isNotEmpty) {
        final days = task.repeatDays!.split(',').map(int.parse).toSet();
        occurrences.addAll(_getWeekdayOccurrences(days, hour, minute, now, windowEnd, task));
      }
    } else if (task.repeatType == 2) {
      // Every N days
      occurrences.addAll(_getIntervalOccurrences(task, hour, minute, now, windowEnd));
    }

    // Schedule each occurrence as a one-shot exact alarm
    for (int i = 0; i < occurrences.length && i < _maxSlotsPerTask; i++) {
      final slotId = _getRecurringSlotId(task.id!, i);
      await _scheduleOneShot(
        id: slotId,
        title: 'Reminder: ${task.title}',
        body: task.isPriority
            ? 'High Priority Task! Check your schedule.'
            : 'Time to work on this task.',
        scheduledTime: occurrences[i],
      );
    }

    debugPrint('Scheduled ${occurrences.length} occurrences for task "${task.title}"');
  }

  List<DateTime> _getWeekdayOccurrences(
    Set<int> weekdays,
    int hour,
    int minute,
    DateTime now,
    DateTime windowEnd,
    RecurringTask task,
  ) {
    final List<DateTime> result = [];
    DateTime cursor = DateTime(now.year, now.month, now.day, hour, minute);
    // If today's slot has already passed, start from tomorrow
    if (!cursor.isAfter(now)) {
      cursor = cursor.add(const Duration(days: 1));
    }

    while (!cursor.isAfter(windowEnd)) {
      if (weekdays.contains(cursor.weekday)) {
        if (_isWithinTaskDateRange(cursor, task)) {
          result.add(cursor);
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  List<DateTime> _getIntervalOccurrences(
    RecurringTask task,
    int hour,
    int minute,
    DateTime now,
    DateTime windowEnd,
  ) {
    if (task.intervalDays == null || task.intervalDays! <= 0) return [];
    final List<DateTime> result = [];

    final startBase = task.fromDate ?? now;
    DateTime cursor = DateTime(startBase.year, startBase.month, startBase.day, hour, minute);

    // Advance past now
    while (!cursor.isAfter(now)) {
      cursor = cursor.add(Duration(days: task.intervalDays!));
    }

    while (!cursor.isAfter(windowEnd)) {
      if (_isWithinTaskDateRange(cursor, task)) {
        result.add(cursor);
      }
      cursor = cursor.add(Duration(days: task.intervalDays!));
    }
    return result;
  }

  bool _isWithinTaskDateRange(DateTime dt, RecurringTask task) {
    if (task.fromDate != null && dt.isBefore(task.fromDate!)) return false;
    if (task.toDate != null && dt.isAfter(
        DateTime(task.toDate!.year, task.toDate!.month, task.toDate!.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  Future<void> cancelRecurringTask(RecurringTask task) async {
    if (task.id == null) return;
    for (int i = 0; i < _maxSlotsPerTask; i++) {
      await _notificationsPlugin.cancel(_getRecurringSlotId(task.id!, i));
    }
  }

  // ---------------------------------------------------------------------------
  // One-Time Task Scheduling
  // ---------------------------------------------------------------------------

  Future<void> scheduleOneTimeTask(OneTimeTask task) async {
    await cancelOneTimeTask(task);

    if (!task.isNotificationEnabled || task.deadline == null || task.isCompleted) {
      return;
    }

    if (task.notificationTime == null) return;

    final timeParts = task.notificationTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    final deadlineDate = task.deadline!;
    final deadlineTime = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day, hour, minute);

    if (task.remindInDays == null) {
      // Standard reminders: 7, 3, 1 days before + on deadline
      await _scheduleSingleReminder(task, deadlineTime, 0);
      await _scheduleSingleReminder(task, deadlineTime.subtract(const Duration(days: 1)), 1);
      await _scheduleSingleReminder(task, deadlineTime.subtract(const Duration(days: 3)), 3);
      await _scheduleSingleReminder(task, deadlineTime.subtract(const Duration(days: 7)), 7);
    } else {
      await _scheduleSingleReminder(task, deadlineTime, 0);
      await _scheduleSingleReminder(
          task, deadlineTime.subtract(Duration(days: task.remindInDays!)), task.remindInDays!);
    }
  }

  Future<void> _scheduleSingleReminder(
      OneTimeTask task, DateTime scheduledTime, int daysBefore) async {
    if (scheduledTime.isBefore(DateTime.now())) return; // Skip past reminders

    final notificationId = _getOneTimeNotificationId(task.id!, daysBefore);
    final body = daysBefore == 0 ? 'Deadline is today!' : 'Deadline in $daysBefore days.';

    await _scheduleOneShot(
      id: notificationId,
      title: 'Task Deadline: ${task.title}',
      body: body,
      scheduledTime: scheduledTime,
    );
  }

  Future<void> cancelOneTimeTask(OneTimeTask task) async {
    if (task.id == null) return;
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 0));
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 1));
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 3));
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 7));
    if (task.remindInDays != null) {
      await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, task.remindInDays!));
    }
  }

  // ---------------------------------------------------------------------------
  // Core one-shot scheduler (no repeating match components)
  // ---------------------------------------------------------------------------

  Future<void> _scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    // Safety: never schedule in the past
    if (tzTime.isBefore(now)) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Exact alarm failed (id=$id): $e. Falling back to inexact.');
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Inexact alarm also failed (id=$id): $e2');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ID Management
  // ---------------------------------------------------------------------------

  /// Recurring slot: 100,000 + taskId*100 + slotIndex (0–59)
  int _getRecurringSlotId(int taskId, int slotIndex) {
    return 100000 + (taskId * 100) + slotIndex;
  }

  /// One-time: 200,000 + taskId*1000 + daysBefore
  int _getOneTimeNotificationId(int taskId, int daysBefore) {
    return 200000 + (taskId * 1000) + daysBefore;
  }
}
