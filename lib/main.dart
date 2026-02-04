import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:provider/provider.dart';

// TIMEZONE IMPORTS
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// CORE IMPORTS
import 'features/home/screens/smart_desk_screen.dart';

// ATTENDANCE IMPORTS
import 'features/attendance/providers/timetable_provider.dart';
import 'features/attendance/providers/attendance_provider.dart';
import 'features/attendance/providers/subject_provider.dart';
import 'features/attendance/services/attendance_notification_service.dart';
import 'features/attendance/screens/quick_attendance_screen.dart';
import 'features/settings/providers/theme_provider.dart';


// -----------------------------------------------------------------------------
// CONFIGURATION & GLOBALS
// -----------------------------------------------------------------------------

const String taskName = "noticeCheckTask";
const String uniqueTaskName = "unique_notice_check_id";
const String channelId = "smartdesk_channel_id";
const String channelName = "SmartDesk Notices";
const String cacheKey = "notice_cache"; // Unified Cache Key

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Attendance notification service instance
late AttendanceNotificationService attendanceNotificationService;

// -----------------------------------------------------------------------------
// 1. BACKGROUND WORKER
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// 1. BACKGROUND WORKER (REMOVED)
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    return Future.value(true);
  });
}


// -----------------------------------------------------------------------------
// 3. MAIN ENTRY POINT
// -----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INITIALIZE TIMEZONES (DATABASE)
  tz.initializeTimeZones();

  // 2. CONFIGURE LOCAL LOCATION (CRITICAL FIX)
  try {
    final timezoneinfo = await FlutterTimezone.getLocalTimezone();
    final timeZoneName = timezoneinfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    // print("Local Timezone set to: $timeZoneName");
  } catch (e) {
    // print("Could not get local timezone: $e");
    // Fallback to UTC if device timezone fails
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // Initialize notifications with response handlers
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
  flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  // Request Notification Permissions (Android 13+)
  await androidImplementation?.requestNotificationsPermission();

  // Request Exact Alarm Permissions (Android 13+)
  // This is required for zonedSchedule to work exactly at the scheduled time
  if (androidImplementation != null) {
    bool? hasPermission = await androidImplementation.canScheduleExactNotifications();
    if (hasPermission == false) {
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Workmanager().initialize(
    callbackDispatcher,
  );

  /*Workmanager().registerPeriodicTask(
    uniqueTaskName,
    taskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );*/

  // Initialize attendance notification service
  attendanceNotificationService = AttendanceNotificationService(flutterLocalNotificationsPlugin);
  await attendanceNotificationService.initialize();

  HttpOverrides.global = MyHttpOverrides();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => SubjectProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// -----------------------------------------------------------------------------
// 4. NOTIFICATION RESPONSE HANDLERS
// -----------------------------------------------------------------------------

/// Handle notification taps and action button clicks when app is in foreground.
void _onNotificationResponse(NotificationResponse response) {
  _handleNotificationResponse(response);
}

/// Handle notification responses when app is in background or terminated.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  _handleNotificationResponse(response);
}

/// Common handler for notification responses.
void _handleNotificationResponse(NotificationResponse response) async {
  final payload = response.payload;
  final actionId = response.actionId;

  // Check if this is an attendance notification
  if (payload == AttendanceNotificationService.payloadAttendance) {
    // Handle action button taps (Present/Absent)
    if (actionId != null && actionId.isNotEmpty) {
      final handled = await AttendanceNotificationService.handleNotificationAction(actionId);
      if (handled) {
        // Action was handled (Present/Absent saved directly)
        return;
      }
    }

    // User tapped on notification body - open the quick attendance screen
    _navigateToQuickAttendance();
  }
}

/// Navigate to the quick attendance screen (now a dialog).
void _navigateToQuickAttendance() {
  final context = navigatorKey.currentContext;
  if (context != null) {
    QuickAttendanceScreen.show(context, DateTime.now());
  }
}

// -----------------------------------------------------------------------------
// 5. APP WIDGET
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'SmartDesk',
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeProvider.themeMode,
          home: SmartDesk(),
        );
      },
    );
  }
}
