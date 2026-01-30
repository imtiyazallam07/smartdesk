
enum TaskType { recurring, oneTime }

class RecurringTask {
  int? id;
  String title;
  int repeatType; // 0: Every working day, 1: Specific days, 2: Interval
  String? repeatDays; // e.g., "1,3,5" for Mon, Wed, Fri
  int? intervalDays; // e.g., 2 for every 2 days
  DateTime? fromDate;
  DateTime? toDate;
  bool isPriority;
  bool isNotificationEnabled;
  String? notificationTime; // HH:mm
  bool isActive;
  String? calendarEventId;

  RecurringTask({
    this.id,
    required this.title,
    required this.repeatType,
    this.repeatDays,
    this.intervalDays,
    this.fromDate,
    this.toDate,
    this.isPriority = false,
    this.isNotificationEnabled = true,
    this.notificationTime,
    this.isActive = true,
    this.calendarEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'repeatType': repeatType,
      'repeatDays': repeatDays,
      'intervalDays': intervalDays,
      'fromDate': fromDate?.toIso8601String(),
      'toDate': toDate?.toIso8601String(),
      'isPriority': isPriority ? 1 : 0,
      'isNotificationEnabled': isNotificationEnabled ? 1 : 0,
      'notificationTime': notificationTime,
      'isActive': isActive ? 1 : 0,
      'calendarEventId': calendarEventId,
    };
  }

  factory RecurringTask.fromMap(Map<String, dynamic> map) {
    return RecurringTask(
      id: map['id'],
      title: map['title'],
      repeatType: map['repeatType'],
      repeatDays: map['repeatDays'],
      intervalDays: map['intervalDays'],
      fromDate: map['fromDate'] != null ? DateTime.parse(map['fromDate']) : null,
      toDate: map['toDate'] != null ? DateTime.parse(map['toDate']) : null,
      isPriority: map['isPriority'] == 1,
      isNotificationEnabled: map['isNotificationEnabled'] == 1,
      notificationTime: map['notificationTime'],
      isActive: map['isActive'] == 1,
      calendarEventId: map['calendarEventId'],
    );
  }
}

class OneTimeTask {
  int? id;
  String title;
  DateTime? deadline;
  bool isNotificationEnabled;
  int? remindInDays; // Custom reminder offset
  String? notificationTime;
  bool isCompleted;
  String? calendarEventId;

  OneTimeTask({
    this.id,
    required this.title,
    this.deadline,
    this.isNotificationEnabled = true,
    this.remindInDays,
    this.notificationTime,
    this.isCompleted = false,
    this.calendarEventId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline?.toIso8601String(),
      'isNotificationEnabled': isNotificationEnabled ? 1 : 0,
      'remindInDays': remindInDays,
      'notificationTime': notificationTime,
      'isCompleted': isCompleted ? 1 : 0,
      'calendarEventId': calendarEventId,
    };
  }

  factory OneTimeTask.fromMap(Map<String, dynamic> map) {
    return OneTimeTask(
      id: map['id'],
      title: map['title'],
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      isNotificationEnabled: map['isNotificationEnabled'] == 1,
      remindInDays: map['remindInDays'],
      notificationTime: map['notificationTime'],
      isCompleted: map['isCompleted'] == 1,
      calendarEventId: map['calendarEventId'],
    );
  }
}
