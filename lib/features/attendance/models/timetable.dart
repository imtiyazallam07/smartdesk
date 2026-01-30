import 'package:flutter/material.dart';

class TimeSlot {
  final String id;
  final String subjectName;
  final int startTimeHour;
  final int startTimeMinute;
  final int endTimeHour;
  final int endTimeMinute;

  TimeSlot({
    required this.id,
    required this.subjectName,
    required this.startTimeHour,
    required this.startTimeMinute,
    required this.endTimeHour,
    required this.endTimeMinute,
  });

  TimeOfDay get startTime => TimeOfDay(hour: startTimeHour, minute: startTimeMinute);
  TimeOfDay get endTime => TimeOfDay(hour: endTimeHour, minute: endTimeMinute);

  String get timeString {
    final start = _formatTime(startTimeHour, startTimeMinute);
    final end = _formatTime(endTimeHour, endTimeMinute);
    return "$start - $end";
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return "$h:$m $period";
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectName': subjectName,
      'startTimeHour': startTimeHour,
      'startTimeMinute': startTimeMinute,
      'endTimeHour': endTimeHour,
      'endTimeMinute': endTimeMinute,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'],
      subjectName: map['subjectName'],
      startTimeHour: map['startTimeHour'],
      startTimeMinute: map['startTimeMinute'],
      endTimeHour: map['endTimeHour'],
      endTimeMinute: map['endTimeMinute'],
    );
  }
}

class DaySchedule {
  final int dayOfWeek; // 1 = Monday
  final List<TimeSlot> slots;

  DaySchedule({required this.dayOfWeek, required this.slots});
}
