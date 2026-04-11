import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../features/todo/services/todo_db_helper.dart';
import '../features/todo/models/todo_model.dart';
import '../features/library/services/library_database_helper.dart';
import '../features/attendance/services/database_helper.dart';
import '../features/attendance/models/timetable.dart';

class WidgetUpdateService {
  static Future<void> updateAllWidgets() async {
    try {
      // 1. TIMETABLE
      final timetableMap = await DatabaseHelper.instance.getAllSlots();
      final dayOfWeek = DateTime.now().weekday;
      
      List<TimeSlot> slots = [];
      if (timetableMap.containsKey(dayOfWeek)) {
        slots = timetableMap[dayOfWeek]!;
      }

      if (slots.isNotEmpty) {
        final slotsData = slots.map((s) {
          final startH = s.startTime.hour.toString().padLeft(2, '0');
          final startM = s.startTime.minute.toString().padLeft(2, '0');
          final endH = s.endTime.hour.toString().padLeft(2, '0');
          final endM = s.endTime.minute.toString().padLeft(2, '0');
          return {
            'subject': s.subjectName,
            'time': '$startH:$startM - $endH:$endM'
          };
        }).toList();
        await HomeWidget.saveWidgetData('timetable_slots', jsonEncode(slotsData));
      } else {
        await HomeWidget.saveWidgetData('timetable_slots', '[]');
      }

      final Map<String, dynamic> allSlotsJson = {};
      timetableMap.forEach((day, slotsList) {
        allSlotsJson[day.toString()] = slotsList.map((s) {
          final startH = s.startTime.hour.toString().padLeft(2, '0');
          final startM = s.startTime.minute.toString().padLeft(2, '0');
          final endH = s.endTime.hour.toString().padLeft(2, '0');
          final endM = s.endTime.minute.toString().padLeft(2, '0');
          return {
            'subject': s.subjectName,
            'time': '$startH:$startM - $endH:$endM'
          };
        }).toList();
      });
      await HomeWidget.saveWidgetData('timetable_slots_all', jsonEncode(allSlotsJson));
      await HomeWidget.updateWidget(androidName: 'TimetableWidget');

      // 2. TASKS
      final allRecurringTasks = await TodoDatabaseHelper.instance.getRecurringTasks();
      final todayTasks = _filterTodayRecurringTasks(allRecurringTasks);

      final allOneTimeTasks = await TodoDatabaseHelper.instance.getOneTimeTasks();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final upcomingTasks = allOneTimeTasks.where((task) {
        if (task.isCompleted) return false;
        if (task.deadline == null) return false;
        final deadlineDate = DateTime(
            task.deadline!.year, task.deadline!.month, task.deadline!.day);
        final daysUntilDeadline = deadlineDate.difference(today).inDays;
        return daysUntilDeadline >= 0 && daysUntilDeadline < 3;
      }).toList();

      final tasksData = [
        ...todayTasks.map((t) => {
          'title': t.title,
          'subtitle': 'Today\'s Task',
          'badge': t.notificationTime != null ? t.notificationTime! : 'All Day'
        }),
        ...upcomingTasks.map((t) {
           final daysLeft = DateTime(t.deadline!.year, t.deadline!.month, t.deadline!.day)
                              .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
           final dateFormatted = '${t.deadline!.day.toString().padLeft(2, '0')}/${t.deadline!.month.toString().padLeft(2, '0')}/${t.deadline!.year}';
           return {
             'title': t.title,
             'subtitle': 'Deadline: $dateFormatted',
             'badge': daysLeft == 0 ? 'DUE TODAY' : '$daysLeft Days Left'
           };
        })
      ].toList();
      await HomeWidget.saveWidgetData('tasks_data', jsonEncode(tasksData));
      await HomeWidget.updateWidget(androidName: 'TasksWidget');

      // 3. BOOKS
      final allBooks = await LibraryDatabaseHelper.instance.readAllBooks();
      var upcomingBooks = allBooks.where((book) {
        if (book.isReturned == 1) return false;
        try {
          DateTime.parse(book.returnDate);
          return true;
        } catch (_) {
          return false;
        }
      }).toList();
      
      upcomingBooks.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.returnDate);
          final dateB = DateTime.parse(b.returnDate);
          return dateA.compareTo(dateB);
        } catch (_) {
          return 0;
        }
      });

      final booksData = upcomingBooks.map((b) {
        final returnDate = DateTime.parse(b.returnDate);
        final daysLeft = DateTime(returnDate.year, returnDate.month, returnDate.day)
                           .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
        final dateFormatted = '${returnDate.day.toString().padLeft(2, '0')}/${returnDate.month.toString().padLeft(2, '0')}/${returnDate.year}';
        return {
          'title': b.title,
          'subtitle': 'Deadline: $dateFormatted',
          'badge': daysLeft == 0 ? 'DUE TODAY' : '$daysLeft Days Left'
        };
      }).toList();
      await HomeWidget.saveWidgetData('books_data', jsonEncode(booksData));
      await HomeWidget.updateWidget(androidName: 'BooksWidget');

    } catch (e) {
      debugPrint('WidgetUpdateService Error: $e');
    }
  }

  static List<RecurringTask> _filterTodayRecurringTasks(List<RecurringTask> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOfWeek = now.weekday;

    return tasks.where((task) {
      if (!task.isActive) return false;
      if (task.fromDate != null) {
        final fromDate = DateTime(
            task.fromDate!.year, task.fromDate!.month, task.fromDate!.day);
        if (today.isBefore(fromDate)) return false;
      }
      if (task.toDate != null) {
        final toDate =
            DateTime(task.toDate!.year, task.toDate!.month, task.toDate!.day);
        if (today.isAfter(toDate)) return false;
      }
      if (task.repeatType == 0) {
        return dayOfWeek >= 1 && dayOfWeek <= 6;
      } else if (task.repeatType == 1) {
        if (task.repeatDays == null || task.repeatDays!.isEmpty) return false;
        try {
          final days =
              task.repeatDays!.split(',').map((s) => int.parse(s.trim())).toList();
          return days.contains(dayOfWeek);
        } catch (_) {
          return false;
        }
      } else if (task.repeatType == 2) {
        if (task.intervalDays == null || task.fromDate == null) return false;
        final fromDate = DateTime(
            task.fromDate!.year, task.fromDate!.month, task.fromDate!.day);
        final daysSinceStart = today.difference(fromDate).inDays;
        return daysSinceStart >= 0 &&
            daysSinceStart % task.intervalDays! == 0;
      }
      return false;
    }).toList();
  }
}
