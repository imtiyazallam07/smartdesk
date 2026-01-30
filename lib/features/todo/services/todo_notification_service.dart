import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/todo_model.dart';

class TodoNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  static const String _channelId = 'todo_channel';
  static const String _channelName = 'Task Reminders';
  static const String _channelDescription = 'Notifications for tasks and reminders';

  TodoNotificationService(this._notificationsPlugin);

  // Initialize (Channel creation is handled in main, but we could safeguard here)
  Future<void> initialize() async {
      // Assuming channel is created or we can create if needed
  }
  
  // --- Recurring Task Scheduling ---

  Future<void> scheduleRecurringTask(RecurringTask task) async {
    if (!task.isNotificationEnabled || task.notificationTime == null || !task.isActive) {
      await cancelRecurringTask(task);
      return;
    }

    final timeParts = task.notificationTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    if (task.repeatType == 0) {
      // Every working day (Mon-Sat, assuming Sat is working based on AttendanceService, or standard Mon-Fri? Context implies Mon-Sat usually in India or specific contexts)
      // "Every working day" usually implies Mon-Fri or Mon-Sat. Let's assume Mon-Sat as per typical student apps or user can specify.
      // Actually, let's look at 'repeatDays' logic. If type is 0, we can hardcode Mon-Sat or match user intent. 
      // The prompt says "every working day*". I'll treat it as Mon-Fri (1-5) or Mon-Sat (1-6). Let's go with Mon-Sat (1-6) as per AttendanceService.
      for (int day = 1; day <= 6; day++) {
        await _scheduleWeekly(task, day, hour, minute);
      }
    } else if (task.repeatType == 1) {
      // Specific days
      if (task.repeatDays != null) {
        final days = task.repeatDays!.split(',').map((e) => int.parse(e)).toList();
        for (final day in days) {
          await _scheduleWeekly(task, day, hour, minute);
        }
      }
    } else if (task.repeatType == 2) {
      // Interval (every N days)
      // This is trickier with native repeating notifications. 
      // Native android 'repeat interval' is limited. 
      // Best approach: Schedule next N occurrences.
      await _scheduleInterval(task, hour, minute);
    }
  }

  Future<void> _scheduleWeekly(RecurringTask task, int dayOfWeek, int hour, int minute) async {
    final notificationId = _getRecurringNotificationId(task.id!, dayOfWeek); // ID based on TaskID + Day
    
    // Calculate first match
    tz.TZDateTime scheduledDate = _nextInstanceOfWeekday(dayOfWeek, hour, minute);

    // Apply from/to date constraints
    if (task.fromDate != null && scheduledDate.isBefore(tz.TZDateTime.from(task.fromDate!, tz.local))) {
       // Find next match that is after fromDate
       while(scheduledDate.isBefore(tz.TZDateTime.from(task.fromDate!, tz.local))) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
       }
    }

    if (task.toDate != null && scheduledDate.isAfter(tz.TZDateTime.from(task.toDate!, tz.local))) {
       // If the very first occurrence is after end date, don't schedule
       return;
    }

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Reminder: ${task.title}',
      task.isPriority ? 'High Priority Task! Check your schedule.' : 'Time to work on this task.',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: task.isPriority ? Importance.max : Importance.defaultImportance,
          priority: task.isPriority ? Priority.high : Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _scheduleInterval(RecurringTask task, int hour, int minute) async {
     // Scheduling only next 10 instances to strictly follow interval logic without flooding ALARMS
     // User will open app eventually and we can reschedule, or WorkManager can handle longer term.
     // For now, schedule upcoming 30 days worth of reminders.
     if (task.intervalDays == null || task.fromDate == null) return;
     
     DateTime startDate = task.fromDate!;
     // Align start date time
     DateTime seedDate = DateTime(startDate.year, startDate.month, startDate.day, hour, minute);
     if (seedDate.isBefore(DateTime.now())) {
        // Adjust to next interval if already passed? Or start from 'From' date strictly?
        // Logic: Start from 'From' date, add intervals until > now.
        while (seedDate.isBefore(DateTime.now())) {
           seedDate = seedDate.add(Duration(days: task.intervalDays!));
        }
     }
     
     tz.TZDateTime scheduledDate = tz.TZDateTime.from(seedDate, tz.local);
     
     // Schedule next 10 occurrences
     for(int i=0; i<10; i++) {
        if (task.toDate != null && scheduledDate.isAfter(tz.TZDateTime.from(task.toDate!, tz.local))) break;
        
        final notificationId = _getRecurringIntervalId(task.id!, i);
        
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          'Reminder: ${task.title}',
          'Recurring task reminder.',
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: task.isPriority ? Importance.max : Importance.defaultImportance,
              priority: task.isPriority ? Priority.high : Priority.defaultPriority,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        
        scheduledDate = scheduledDate.add(Duration(days: task.intervalDays!));
     }
  }

  Future<void> cancelRecurringTask(RecurringTask task) async {
    // Determine range of IDs to cancel
    if (task.id == null) return;
    
    // Type 0 & 1 (Weekly): IDs 100,000 + TaskID*100 + [1-7]
    for (int i=1; i<=7; i++) {
       await _notificationsPlugin.cancel(_getRecurringNotificationId(task.id!, i));
    }
    
    // Type 2 (Interval): IDs 100,000 + TaskID*100 + [0-50] (Safe upper bound)
    for (int i=0; i<=50; i++) {
       await _notificationsPlugin.cancel(_getRecurringIntervalId(task.id!, i));
    }
  }

  // --- One-Time Task Scheduling ---

  Future<void> scheduleOneTimeTask(OneTimeTask task) async {
    if (!task.isNotificationEnabled || task.deadline == null || task.isCompleted) {
       await cancelOneTimeTask(task);
       return;
    }

    if (task.notificationTime == null) return; // Need time
    
    final timeParts = task.notificationTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    // Deadlines
    final deadlineDate = task.deadline!;
    final deadlineTime = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day, hour, minute);

    // Schedule on deadline
    if (task.remindInDays == null) {
       // Standard reminders: 7, 3, 1 days before + On Deadline
       await _scheduleSingleReminder(task, deadlineTime, 0); // On day
       await _scheduleSingleReminder(task, deadlineTime.subtract(const Duration(days: 1)), 1);
       await _scheduleSingleReminder(task, deadlineTime.subtract(const Duration(days: 3)), 3);
       await _scheduleSingleReminder(task, deadlineTime.subtract(const Duration(days: 7)), 7);
    } else {
       // Custom reminder
       await _scheduleSingleReminder(task, deadlineTime, 0); // Always remind on deadline? Prompt implies "remind in given days", could mean ONLY then or deadline also.
       // "if remind in how many days field is empty else remind in given days" -> Likely means replace standard reminders with this one custom reminder.
       // It also says "Allow notification... remind on deadline if empty" - implying if remindInDays is set, it might be the only reminder OR it's an offset.
       // "remind in how many days" -> usually "Remind me 2 days before".
       // Let's assume deadline + custom offset.
       await _scheduleSingleReminder(task, deadlineTime.subtract(Duration(days: task.remindInDays!)), task.remindInDays!);
    }
  }

  Future<void> _scheduleSingleReminder(OneTimeTask task, DateTime scheduledTime, int daysBefore) async {
     if (scheduledTime.isBefore(DateTime.now())) return; // Don't schedule past

     final notificationId = _getOneTimeNotificationId(task.id!, daysBefore);

     String body = daysBefore == 0 
        ? 'Deadline is today!' 
        : 'Deadline in $daysBefore days.';

     await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Task Deadline: ${task.title}',
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
     );
  }

  Future<void> cancelOneTimeTask(OneTimeTask task) async {
     if (task.id == null) return;
     // Cancel potential offsets: 0, 1, 3, 7, and custom (safe range 0-365?)
    // This is hard because custom offset could be anything.
    // Better strategy: We can't easily guess custom offset ID if not stored.
    // However, since ID is deterministic based on daysBefore, if we know remindInDays we can cancel it.
    
    // Standard
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 0));
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 1));
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 3));
    await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, 7));
    
    // Custom
    if (task.remindInDays != null) {
       await _notificationsPlugin.cancel(_getOneTimeNotificationId(task.id!, task.remindInDays!));
    }
  }

  // --- ID Management ---
  // Large offsets to avoid colliding with Attendance (100-200 range)
  
  int _getRecurringNotificationId(int taskId, int subId) {
     // Range: 100,000 + ...
     return 100000 + (taskId * 100) + subId;
  }
  
  int _getRecurringIntervalId(int taskId, int index) {
     return 100000 + (taskId * 100) + 50 + index; 
  }

  int _getOneTimeNotificationId(int taskId, int daysBefore) {
     // Range: 200,000 + ...
     // daysBefore is offset.
     return 200000 + (taskId * 1000) + daysBefore;
  }

  // --- Helper Date Logic ---
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
