import 'package:flutter/material.dart';
import '../models/timetable.dart';
import '../services/database_helper.dart';

class TimetableProvider with ChangeNotifier {
  bool _isInit = false;
  Map<int, List<TimeSlot>> _timetable = {};

  Map<int, List<TimeSlot>> get timetable => _timetable;

  Future<void> init() async {
    if (_isInit) return;
    await _loadTimetable();
    _isInit = true;
  }

  Future<void> refreshTimetable() async {
    await _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    _timetable = await DatabaseHelper.instance.getAllSlots();
    notifyListeners();
  }

  DaySchedule? getScheduleForDay(int dayOfWeek) {
    if (_timetable.containsKey(dayOfWeek)) {
      return DaySchedule(dayOfWeek: dayOfWeek, slots: _timetable[dayOfWeek]!);
    }
    return null;
  }

  Future<void> addSlot(int dayOfWeek, TimeSlot slot) async {
    await DatabaseHelper.instance.addSlot(dayOfWeek, slot);
    await _loadTimetable();
  }
  
  Future<void> updateSlot(int dayOfWeek, TimeSlot slot) async {
    await DatabaseHelper.instance.updateSlot(dayOfWeek, slot);
    await _loadTimetable();
  }

  Future<void> deleteSlot(String slotId) async {
    await DatabaseHelper.instance.deleteSlot(slotId);
    await _loadTimetable();
  }
}
