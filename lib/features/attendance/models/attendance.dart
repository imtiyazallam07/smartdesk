import 'dart:convert';
import 'package:intl/intl.dart';

enum AttendanceStatus {
  present,
  absent,
  partial,
  holiday, 
  notMarked,
  weeklyOff
}

class DailyAttendance {
  final DateTime date;
  AttendanceStatus status;
  Map<String, bool> slotAttendance; // slotId -> isPresent
  Map<String, String> slotSubjects; // slotId -> SubjectName (Snapshot)
  String? note;

  DailyAttendance({
    required this.date, 
    required this.status, 
    this.slotAttendance = const {}, 
    this.slotSubjects = const {},
    this.note
  });
  
  Map<String, dynamic> toMap() {
    return {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'status': status.index,
        'slotAttendance': jsonEncode(slotAttendance),
        'slotSubjects': jsonEncode(slotSubjects),
        'note': note
    };
  }
  
  static DailyAttendance fromMap(Map<String, dynamic> map) {
      return DailyAttendance(
          date: DateTime.parse(map['date']),
          status: AttendanceStatus.values[map['status']],
          slotAttendance: Map<String, bool>.from(jsonDecode(map['slotAttendance'])),
          slotSubjects: map['slotSubjects'] != null ? Map<String, String>.from(jsonDecode(map['slotSubjects'])) : {},
          note: map['note']
      );
  }
}
