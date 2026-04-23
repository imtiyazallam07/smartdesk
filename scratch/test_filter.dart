import 'dart:convert';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dayOfWeek = now.weekday;
  
  print('Now: $now, today: $today, dayOfWeek: $dayOfWeek');

  // Test RepeatType = 0
  bool isType0Match = dayOfWeek >= 1 && dayOfWeek <= 6;
  print('Is Type 0 match? $isType0Match');

  // Let's create a task fromDate = today, but parsing it from Iso8601 string
  final fromDateStr = today.toIso8601String();
  final parsedFromDate = DateTime.parse(fromDateStr);
  print('Parsed From Date: $parsedFromDate');
  print('today.isBefore(parsedFromDate): ${today.isBefore(parsedFromDate)}');

}
