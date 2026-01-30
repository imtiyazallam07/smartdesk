import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/todo_model.dart';
// Note: We need a way to calculate the next instance date. 
// Ideally, we reuse logic from TodoNotificationService or duplicate it here for simplicity.
// For now, I will add helper methods here to calculate timestamps.

class CalendarSyncService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  CalendarSyncService();

  Future<bool> hasPermissions() async {
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        return false;
      }
    }
    return true;
  }

  Future<String?> addToCalendar({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!await hasPermissions()) return null;

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || (calendarsResult.data?.isEmpty ?? true)) return null;

    // Use the first writable calendar or a default one
    Calendar? targetCalendar;
    try {
      targetCalendar = calendarsResult.data!.firstWhere((c) => c.isReadOnly == false && c.isDefault == true);
    } catch (_) {
      try {
        targetCalendar = calendarsResult.data!.firstWhere((c) => c.isReadOnly == false);
      } catch (_) {
        return null; 
      }
    }

    // ignore: unnecessary_null_comparison, dead_code
    if (targetCalendar == null) return null;

    final event = Event(
      targetCalendar.id,
      title: title,
      description: description,
      start: tz.TZDateTime.from(startTime, tz.local),
      end: tz.TZDateTime.from(endTime, tz.local),
    );

    final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
    if (result!.isSuccess && result.data != null) {
      return result.data;
    }
    return null;
  }

  Future<void> removeFromCalendar(String? eventId) async {
    if (eventId == null) return;
    if (!await hasPermissions()) return;

    final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data!.isEmpty) return;

    // We don't know which calendar the event is in, so we might need to try deleting from the likely ones 
    // or store calendarId. For simplicity, we try the default writable ones.
    // Optimization: 'device_calendar' deleteEvent requires calendarId. 
    // If we didn't store calendarId, we have to guess. 
    // To fix this robustly, we should iterate.
    
    for (final calendar in calendarsResult.data!) {
      if (calendar.isReadOnly == false) {
         try {
           final result = await _deviceCalendarPlugin.deleteEvent(calendar.id, eventId);
           if (result.isSuccess && result.data == true) return; // Deleted
         } catch (_) {}
      }
    }
  }

  // --- Helpers for Next Instance ---
  
  DateTime? getNextInstanceForRecurring(RecurringTask task) {
    if (task.notificationTime == null) return null;

    final timeParts = task.notificationTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    DateTime now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);

    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    // Logic similar to notification service
    if (task.repeatType == 0) { // Every working day (Mon-Sat = 1-6)
      while (candidate.weekday == DateTime.sunday) {
         candidate = candidate.add(const Duration(days: 1));
      }
    } else if (task.repeatType == 1) { // Specific days
      if (task.repeatDays == null || task.repeatDays!.isEmpty) return null;
      final days = task.repeatDays!.split(',').map(int.parse).toList();
      while (!days.contains(candidate.weekday)) {
        candidate = candidate.add(const Duration(days: 1));
      }
    } else if (task.repeatType == 2) { // Interval
       if (task.intervalDays == null || task.fromDate == null) return null;
       DateTime start = task.fromDate!;
       DateTime base = DateTime(start.year, start.month, start.day, hour, minute);
       // Find next occurrence >= now
       while (base.isBefore(now)) {
         base = base.add(Duration(days: task.intervalDays!));
       }
       candidate = base;
    }

    // Constraints
    if (task.toDate != null) {
      DateTime end = task.toDate!.add(const Duration(days: 1)); // End of day
      if (candidate.isAfter(end)) return null;
    }

    // From Date
    if (task.fromDate != null) {
       DateTime start = DateTime(task.fromDate!.year, task.fromDate!.month, task.fromDate!.day, hour, minute);
       if (candidate.isBefore(start)) candidate = start;
    }

    return candidate;
  }

  DateTime? getNextInstanceForOneTime(OneTimeTask task) {
    if (task.notificationTime == null || task.deadline == null) return null;
    
    final timeParts = task.notificationTime!.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    
    DateTime deadline = task.deadline!;
    return DateTime(deadline.year, deadline.month, deadline.day, hour, minute);
  }
}
