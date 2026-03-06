import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/database_helper.dart';
import '../services/attendance_notification_service.dart';

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

    final list = await DatabaseHelper.instance.getAttendanceForMonth(year, month);

    for (var att in list) {
      final key = DateTime(att.date.year, att.date.month, att.date.day);
      _cache[key] = att;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Loads ALL attendance records (from the beginning) into the cache
  Future<void> loadAll() async {
    _isLoading = true;

    final list = await DatabaseHelper.instance.getAllAttendance();

    _cache.clear();
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
    
    // Cancel the notification for this date if it was scheduled
    await AttendanceNotificationService.cancelNotificationForDate(attendance.date);
    
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

  /// Returns subject-wise stats for a specific month (used for monthly view)
  Map<String, Map<String, dynamic>> getMonthlySubjectStats(int year, int month) {
    return _computeSubjectStats(
      (date) => date.year == year && date.month == month,
    );
  }

  /// Returns subject-wise stats across ALL recorded attendance (beginning to now)
  Map<String, Map<String, dynamic>> getAllSubjectStats() {
    return _computeSubjectStats((_) => true);
  }

  /// Returns a chronologically sorted list of {date, percentage} data points
  /// for [subjectName], computed cumulatively from the first recorded class.
  List<Map<String, dynamic>> getSubjectDailyHistory(String subjectName) {
    // Collect all relevant entries for this subject
    final entries = <MapEntry<DateTime, DailyAttendance>>[];

    _cache.forEach((date, d) {
      if (d.status == AttendanceStatus.holiday ||
          d.status == AttendanceStatus.weeklyOff ||
          d.status == AttendanceStatus.notMarked) return;
      if (!d.slotSubjects.values.contains(subjectName)) return;
      entries.add(MapEntry(date, d));
    });

    entries.sort((a, b) => a.key.compareTo(b.key));

    final List<Map<String, dynamic>> history = [];
    int cumulativePresent = 0;
    int cumulativeTotal = 0;

    for (final entry in entries) {
      final date = entry.key;
      final d = entry.value;

      // Count slots belonging to this subject on this day
      d.slotSubjects.forEach((slotId, name) {
        if (name != subjectName) return;
        cumulativeTotal += 1;

        bool isPresent = false;
        if (d.status == AttendanceStatus.present) {
          isPresent = true;
        } else if (d.status == AttendanceStatus.partial) {
          isPresent = d.slotAttendance[slotId] ?? false;
        }
        if (isPresent) cumulativePresent += 1;
      });

      final pct = cumulativeTotal > 0
          ? (cumulativePresent / cumulativeTotal) * 100
          : 0.0;

      history.add({
        'date': date,
        'percentage': pct,
        'present': cumulativePresent,
        'total': cumulativeTotal,
      });
    }

    return history;
  }

  /// Internal helper: computes subject stats for cache entries matching [filter]
  Map<String, Map<String, dynamic>> _computeSubjectStats(
    bool Function(DateTime date) filter,
  ) {
    final Map<String, Map<String, dynamic>> stats = {};

    void initSub(String name) {
      if (!stats.containsKey(name)) {
        stats[name] = {'present': 0, 'total': 0, 'percentage': 0.0};
      }
    }

    _cache.forEach((date, d) {
      if (!filter(date)) return;

      if (d.status == AttendanceStatus.holiday ||
          d.status == AttendanceStatus.weeklyOff ||
          d.status == AttendanceStatus.notMarked) {
        return;
      }

      if (d.slotSubjects.isEmpty) return;

      d.slotSubjects.forEach((slotId, subjectName) {
        initSub(subjectName);
        stats[subjectName]!['total'] += 1;

        bool isSlotPresent = false;

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
    });

    stats.forEach((name, data) {
      if (data['total'] > 0) {
        data['percentage'] = (data['present'] / data['total']) * 100;
      }
    });

    return stats;
  }
}