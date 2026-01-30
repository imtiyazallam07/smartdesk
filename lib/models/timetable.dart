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

  String get timeString {
    final start = '${startTimeHour.toString().padLeft(2,'0')}:${startTimeMinute.toString().padLeft(2,'0')}';
    final end = '${endTimeHour.toString().padLeft(2,'0')}:${endTimeMinute.toString().padLeft(2,'0')}';
    return '$start - $end';
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

  static TimeSlot fromMap(Map<String, dynamic> map) {
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
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final List<TimeSlot> slots;

  DaySchedule({required this.dayOfWeek, required this.slots});
}

class WeeklySchedule {
    final Map<int, DaySchedule> schedules;

    WeeklySchedule({required this.schedules});
}
