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
                _buildCalendar(provider),
                const SizedBox(height: 12),
                _buildStats(provider),
                const SizedBox(height: 20),
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

    if (subjectStats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text("No attendance data for this month.", style: TextStyle(color: Colors.grey)),
      );
    }

    final subjectNames = subjectStats.keys.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 4.5,
          mainAxisSpacing: 12,
        ),
        itemCount: subjectNames.length,
        itemBuilder: (context, index) {
          final subject = subjectNames[index];
          final stats = subjectStats[subject]!;
          final double percentage = stats['percentage'];
          final int present = stats['present'];
          final int total = stats['total'];
          
          // Determine color based on attendance percentage
          final Color themeColor;
          if (percentage >= 80) {
            themeColor = Colors.green;
          } else if (percentage >= 75) {
            themeColor = Colors.amber;
          } else if (percentage >= 60) {
            themeColor = Colors.deepOrange;
          } else {
            themeColor = Colors.red;
          }
          
          // Calculate classes required for 75%
          final int classesRequired = percentage >= 75.0
              ? 0
              : (3 * total - 4 * present).ceil();

          return GestureDetector(
            onTap: () {
              // Optional: Navigate to subject detail screen
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Small circular progress indicator
                  Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: percentage / 100,
                            strokeWidth: 6,
                            backgroundColor: themeColor.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                            strokeCap: StrokeCap.round,
                          ),
                          Text(
                            "${percentage.toInt()}%",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Subject details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Classes: $present / $total",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Classes required for 75%: $classesRequired",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}