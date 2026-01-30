import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HolidayService {
  static const String _holidayCacheKey = "holiday_cache_v1";

  /// Returns a Set of all holiday dates (normalized to midnight) from cache.
  Future<Set<DateTime>> getHolidays() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<DateTime> holidayDates = {};

    // 1. Load from cache
    if (prefs.containsKey(_holidayCacheKey)) {
      try {
        List<dynamic> holidays = jsonDecode(prefs.getString(_holidayCacheKey)!);
        final dateFormat = DateFormat('dd.MM.yyyy');

        for (var item in holidays) {
          if (item['date'] != null) {
            try {
              // Parse "26.01.2026"
              final date = dateFormat.parse(item['date']);
              holidayDates.add(DateTime(date.year, date.month, date.day));
            } catch (e) {
              // Ignore invalid dates
            }
          }
        }
      } catch (e) {
        // Ignore cache errors
      }
    }
    return holidayDates;
  }

  /// Checks if a specific date is a holiday.
  Future<bool> isHoliday(DateTime date) async {
    final holidays = await getHolidays();
    final normalized = DateTime(date.year, date.month, date.day);
    
    // Check if it matches any holiday
    // Note: Set lookup is O(1) mostly, but we need to ensure hashCode equality for DateTime.
    // DateTime normalized to YMD should have same hashCode.
    return holidays.any((h) => 
       h.year == normalized.year && 
       h.month == normalized.month && 
       h.day == normalized.day
    );
  }

  Future<DateTime> getNextWorkingDay() async {
    final holidayDates = await getHolidays();
    
    // Start checking from tomorrow
    DateTime checkDate = DateTime.now().add(const Duration(days: 1));
    
    // Limit loop to avoid infinite loop (e.g. 1 year)
    for (int i = 0; i < 365; i++) {
        final normalizedDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
        
        // Check if Sunday
        if (checkDate.weekday == DateTime.sunday) {
            checkDate = checkDate.add(const Duration(days: 1));
            continue;
        }

        // Check if Holiday
        bool isHoliday = holidayDates.any((h) => 
            h.year == normalizedDate.year && 
            h.month == normalizedDate.month && 
            h.day == normalizedDate.day
        );

        if (isHoliday) {
            checkDate = checkDate.add(const Duration(days: 1));
            continue;
        }

        // It is a working day
        return checkDate;
    }
    
    // Fallback
    return DateTime.now().add(const Duration(days: 1));
  }
}
