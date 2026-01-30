import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import 'day_attendance_screen.dart';
import 'timetable_setup_screen.dart';
import 'subject_management_screen.dart';
import 'quick_attendance_screen.dart';
import '../../../main.dart' show attendanceNotificationService;
import '../services/holiday_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _currentSubjectIndex = 0;
  String _nextWorkingDayText = "Calculating...";

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    Future.microtask(() => _loadData());
    _loadNextWorkingDay();
  }

  Future<void> _loadNextWorkingDay() async {
    final date = await HolidayService().getNextWorkingDay();
    // Format: "Monday, 26 Jan"
    if (mounted) {
      setState(() {
        _nextWorkingDayText = DateFormat('EEEE, d MMM').format(date);
      });
    }
  }

  void _loadData() {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    attendanceProvider.loadMonth(_focusedDay.year, _focusedDay.month);
    Provider.of<TimetableProvider>(context, listen: false).init();
    Provider.of<SubjectProvider>(context, listen: false).loadSubjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Tracker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubjectManagementScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableSetupScreen())),
          )
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildNextWorkingDayCard(),
                _buildCalendar(provider),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1),
                ),
                const SizedBox(height: 20),
                _buildStats(provider),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(AttendanceProvider provider) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2030),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DayAttendanceScreen(date: selectedDay)),
          ).then((_) => provider.loadMonth(_focusedDay.year, _focusedDay.month));
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
          provider.loadMonth(focusedDay.year, focusedDay.month);
        },
        eventLoader: (day) {
          final att = provider.getAttendance(day);
          return (att != null && att.status != AttendanceStatus.notMarked) ? [att] : [];
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            final att = events.first as DailyAttendance;
            Color color;
            switch (att.status) {
              case AttendanceStatus.present: color = Colors.green; break;
              case AttendanceStatus.absent: color = Colors.red; break;
              case AttendanceStatus.partial: color = Colors.orange; break;
              case AttendanceStatus.holiday: color = Colors.blue; break;
              default: return null;
            }
            return Positioned(
              bottom: 4,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStats(AttendanceProvider provider) {
    final subjectStats = provider.getMonthlySubjectStats(_focusedDay.year, _focusedDay.month);

    // Overview fallback if no subject data exists
    final overview = provider.getMonthlyOverviewStats(_focusedDay.year, _focusedDay.month);
    final bool hasSubjectData = subjectStats.isNotEmpty;

    if (!hasSubjectData && (overview['present']! + overview['absent']!) == 0) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text("No attendance data for this month.", style: TextStyle(color: Colors.grey)),
      );
    }

    if (hasSubjectData) {
      final subjectNames = subjectStats.keys.toList();
      // Safety check for index out of bounds
      if (_currentSubjectIndex >= subjectNames.length) _currentSubjectIndex = 0;

      final currentSubject = subjectNames[_currentSubjectIndex];
      final double percentage = subjectStats[currentSubject]!['percentage'];
      final Color themeColor = Colors.primaries[currentSubject.hashCode % Colors.primaries.length];

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left Navigation Arrow
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 45, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _currentSubjectIndex = (_currentSubjectIndex - 1 + subjectNames.length) % subjectNames.length;
                  });
                },
              ),
              const SizedBox(width: 15),
              // Donut Chart with Percentage
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 14,
                      backgroundColor: themeColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${percentage.toStringAsFixed(1)}%",
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const Text("Attendance", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 15),
              // Right Navigation Arrow
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 45, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _currentSubjectIndex = (_currentSubjectIndex + 1) % subjectNames.length;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Subject Name
          Text(
            currentSubject,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Classes: ${subjectStats[currentSubject]!['present']} / ${subjectStats[currentSubject]!['total']}",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, letterSpacing: 0.5),
          ),
          Text((percentage < 75) ? ("No. of Classes required for 75%: ${3 * subjectStats[currentSubject]!['total'] - 4 * subjectStats[currentSubject]!['present'] }") : "Attendance already above 75%"),
        ],
      );
    }

    // Default Overview if subject slots are not yet configured for the month
    return _buildOverviewDonut(overview);
  }

  Widget _buildOverviewDonut(Map<String, int> overview) {
    int total = overview['present']! + overview['absent']!;
    double percent = total == 0 ? 0 : (overview['present']! / total) * 100;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150, height: 150,
              child: CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 12,
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                strokeCap: StrokeCap.round,
              ),
            ),
            Text("${percent.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        const Text("Monthly Overview (All Subjects)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        Text("Total Days Marked: $total", style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildNextWorkingDayCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                "Next Working Day",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nextWorkingDayText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}