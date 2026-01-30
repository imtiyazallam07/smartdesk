import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import 'day_attendance_screen.dart';

/// Quick attendance screen shown when user taps on the notification.
/// Provides 4 options: Present, Absent, Partially Present, Holiday.
class QuickAttendanceScreen extends StatelessWidget {
  final DateTime date;

  const QuickAttendanceScreen({super.key, required this.date});

  /// Show as a dialog
  static Future<void> show(BuildContext context, DateTime date) async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          child: QuickAttendanceScreen(date: date),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date display
          Column(
            children: [
              Icon(
                Icons.calendar_today,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('EEEE, MMMM d').format(date),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How was your attendance today?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Attendance options
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _AttendanceOptionCard(
                icon: Icons.check_circle,
                label: 'Present',
                color: Colors.green,
                onTap: () => _markAttendance(context, AttendanceStatus.present),
              ),
              _AttendanceOptionCard(
                icon: Icons.cancel,
                label: 'Absent',
                color: Colors.red,
                onTap: () => _markAttendance(context, AttendanceStatus.absent),
              ),
              _AttendanceOptionCard(
                icon: Icons.timelapse,
                label: 'Partially Present',
                color: Colors.orange,
                onTap: () => _openPartialAttendance(context),
              ),
              _AttendanceOptionCard(
                icon: Icons.beach_access,
                label: 'Holiday',
                color: Colors.blue,
                onTap: () => _markAttendance(context, AttendanceStatus.holiday),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markAttendance(BuildContext context, AttendanceStatus status) async {
    final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
    final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
    
    final dayOfWeek = date.weekday;
    final daySchedule = timetableProvider.getScheduleForDay(dayOfWeek);
    
    // Build slot data from timetable
    final Map<String, bool> slotAttendance = {};
    final Map<String, String> slotSubjects = {};
    
    if (daySchedule != null) {
      for (var slot in daySchedule.slots) {
        slotSubjects[slot.id] = slot.subjectName;
        slotAttendance[slot.id] = (status == AttendanceStatus.present);
      }
    }
    
    final attendance = DailyAttendance(
      date: date,
      status: status,
      slotAttendance: slotAttendance,
      slotSubjects: slotSubjects,
    );
    
    await attProvider.markAttendance(attendance);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance marked: ${_getStatusLabel(status)}'),
          backgroundColor: _getStatusColor(status),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Close the dialog
      Navigator.of(context).pop();
    }
  }

  void _openPartialAttendance(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DayAttendanceScreen(date: date),
      ),
    );
  }

  String _getStatusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.partial:
        return 'Partially Present';
      case AttendanceStatus.holiday:
        return 'Holiday';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.partial:
        return Colors.orange;
      case AttendanceStatus.holiday:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _AttendanceOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttendanceOptionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(25),
                color.withAlpha(12),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
