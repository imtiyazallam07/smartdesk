import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';

class AttendanceProvider with ChangeNotifier {
  final Map<DateTime, DailyAttendance> _cache = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// Returns attendance for a specific date from the cache
  DailyAttendance? getAttendance(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _cache[key];
  }

  /// Initializer called at app start
  Future<void> init() async {
    notifyListeners();
  }

  /// Loads all attendance records for a specific month into the cache
  Future<void> loadMonth(int year, int month) async {
    _isLoading = true;
    // We don't notifyListeners here to prevent mid-load UI flickering

    final list = await DatabaseHelper.instance.getAttendanceForMonth(year, month);

    // Clear old cache for this specific month logic if needed,
    // but here we just update/fill to keep performance snappy
    for (var att in list) {
      final key = DateTime(att.date.year, att.date.month, att.date.day);
      _cache[key] = att;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Saves attendance to DB and updates local cache immediately
  Future<void> markAttendance(DailyAttendance attendance) async {
    await DatabaseHelper.instance.markAttendance(attendance);
    final key = DateTime(attendance.date.year, attendance.date.month, attendance.date.day);
    _cache[key] = attendance;
    notifyListeners();
  }

  /// Deletes attendance from DB and updates local cache immediately
  Future<void> deleteAttendance(DateTime date) async {
    await DatabaseHelper.instance.deleteAttendance(date);
    final key = DateTime(date.year, date.month, date.day);
    _cache.remove(key);
    notifyListeners();
  }

  /// Returns data for the fallback Pie Chart (Present vs Absent days)
  Map<String, int> getMonthlyOverviewStats(int year, int month) {
    int present = 0;
    int absent = 0;
    int partial = 0;

    _cache.forEach((date, data) {
      if (date.year == year && date.month == month) {
        switch (data.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.absent:
            absent++;
            break;
          case AttendanceStatus.partial:
            partial++;
            break;
          default:
            break;
        }
      }
    });

    return {
      'present': present,
      'absent': absent,
      'partial': partial,
    };
  }

  /// Returns data for the detailed Subject-wise Pie Chart
  Map<String, Map<String, dynamic>> getMonthlySubjectStats(int year, int month) {
    final Map<String, Map<String, dynamic>> stats = {};

    void initSub(String name) {
      if (!stats.containsKey(name)) {
        stats[name] = {'present': 0, 'total': 0, 'percentage': 0.0};
      }
    }

    _cache.forEach((date, d) {
      if (date.year == year && date.month == month) {
        // Skip non-attendance days
        if (d.status == AttendanceStatus.holiday ||
            d.status == AttendanceStatus.weeklyOff ||
            d.status == AttendanceStatus.notMarked) {
          return;
        }

        // If there are no specific subjects recorded for this day, we can't do subject stats
        if (d.slotSubjects.isEmpty) return;

        d.slotSubjects.forEach((slotId, subjectName) {
          initSub(subjectName);
          stats[subjectName]!['total'] += 1;

          bool isSlotPresent = false;

          // Logic: If the whole day is marked Present, every subject that day is Present.
          // If marked Partial, we check the specific slot checkbox.
          if (d.status == AttendanceStatus.present) {
            isSlotPresent = true;
          } else if (d.status == AttendanceStatus.absent) {
            isSlotPresent = false;
          } else if (d.status == AttendanceStatus.partial) {
            isSlotPresent = d.slotAttendance[slotId] ?? false;
          }

          if (isSlotPresent) {
            stats[subjectName]!['present'] += 1;
          }
        });
      }
    });

    // Calculate final percentages for the Pie Chart
    stats.forEach((name, data) {
      if (data['total'] > 0) {
        data['percentage'] = (data['present'] / data['total']) * 100;
      }
    });

    return stats;
  }
}