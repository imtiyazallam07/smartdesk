import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import 'database_helper.dart';
import 'holiday_service.dart';

/// Service for managing daily attendance notifications.
/// 
/// Schedules notifications at exactly 6pm IST on working days (Mon-Sat)
/// with action buttons for Present/Absent.
/// 
/// Updated to skip holidays dynamically by scheduling 30 days in advance.
class AttendanceNotificationService {
  static const String _channelId = 'attendance_channel';
  static const String _channelName = 'Attendance Reminders';
  static const String _channelDescription = 'Daily attendance reminder notifications';

  // Base ID. We will use 101-106 for Mon-Sat.
  static const int _baseNotificationId = 100;

  static const String actionPresent = 'PRESENT';
  static const String actionAbsent = 'ABSENT';
  static const String payloadAttendance = 'attendance_notification';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  AttendanceNotificationService(this._notificationsPlugin);
  Future<void> initialize() async {
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Schedule notifications for the next 30 days
    await scheduleUpcomingNotifications();
  }

  /// Schedules daily notifications for the next 30 days, skipping Sundays and holidays.
  Future<void> scheduleUpcomingNotifications() async {
    // 1. Cancel legacy weekly recurring notifications (IDs 101-106)
    for (int day = 1; day <= 6; day++) {
      await _notificationsPlugin.cancel(_baseNotificationId + day);
    }

    final holidayService = HolidayService();
    final now = DateTime.now();
    final tz.TZDateTime tzNow = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < 30; i++) {
        final date = now.add(Duration(days: i));
        
        // Skip Sundays
        if (date.weekday == DateTime.sunday) continue;
        
        // Skip Holidays
        if (await holidayService.isHoliday(date)) continue;
        
        // Generate unique ID based on date (YYYYMMDD)
        final int notificationId = int.parse("${date.year}${date.month.toString().padLeft(2,'0')}${date.day.toString().padLeft(2,'0')}");
        
        // Construct scheduled time (6:00 PM)
        final scheduledDate = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          18, 0, 0
        );

        // Calculate time difference
        // If the time has already passed for today, skips scheduling for today
        if (scheduledDate.isBefore(tzNow)) continue;

        await _notificationsPlugin.zonedSchedule(
          notificationId,
          'Mark Your Attendance',
          'Did you attend your classes today?',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.max,
              priority: Priority.high,
              ongoing: false,
              autoCancel: true,
              category: AndroidNotificationCategory.reminder,
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  actionPresent,
                  'Present',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  actionAbsent,
                  'Absent',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ],
            ),
          ),
          // Use absoluteTime since we are calculating specific dates
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          // matchDateTimeComponents: DateTimeComponents.time, // REMOVED: We want one-off notifications per ID
          // matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // REMOVED: We don't want weekly repeat
          payload: payloadAttendance,
        );
    }
  }

  /// Show the attendance notification immediately (for testing).

  /// Handle notification action button taps.
  static Future<bool> handleNotificationAction(String? actionId) async {
    if (actionId == null) return false;

    AttendanceStatus? status;

    if (actionId == actionPresent) {
      status = AttendanceStatus.present;
    } else if (actionId == actionAbsent) {
      status = AttendanceStatus.absent;
    }

    if (status != null) {
      await _saveAttendanceFromNotification(status);
      return true;
    }

    return false;
  }

  /// Save attendance directly to database from notification action.
  static Future<void> _saveAttendanceFromNotification(AttendanceStatus status) async {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);

    final existing = await DatabaseHelper.instance.getAttendance(date);

    final attendance = DailyAttendance(
      date: date,
      status: status,
      slotAttendance: existing?.slotAttendance ?? {},
      slotSubjects: existing?.slotSubjects ?? {},
      note: existing?.note,
    );

    await DatabaseHelper.instance.markAttendance(attendance);
  }

  /// Cancel all scheduled attendance notifications.
  Future<void> cancelAll() async {
    // Cancel legacy
    for (int i = 1; i <= 6; i++) {
        await _notificationsPlugin.cancel(_baseNotificationId + i);
    }
    // Note: To cancel all future date-based notifications, we would need to track them or iterate significantly.
    // For now, cancelAll is mostly used for testing or full reset.
    // We can iterate next 60 days to be safe.
    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
         final date = now.add(Duration(days: i));
         final int id = int.parse("${date.year}${date.month.toString().padLeft(2,'0')}${date.day.toString().padLeft(2,'0')}");
         await _notificationsPlugin.cancel(id);
    }
  }
}