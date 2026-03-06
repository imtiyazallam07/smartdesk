import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Emulate IST

  // Emulate a book return date
  final DateTime returnDate = DateTime.parse("2026-02-27 12:00:00");
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  
  print("NOW: $now");
  print("RETURN DATE: $returnDate");
  print("===================");

  final triggers = [7, 3, 1, 0];

  for (final daysBefore in triggers) {
    print("Evaluating $daysBefore days before return:");

    final DateTime triggerDate = returnDate.subtract(Duration(days: daysBefore));

    tz.TZDateTime scheduledTime = tz.TZDateTime(
      tz.local,
      triggerDate.year,
      triggerDate.month,
      triggerDate.day,
      7, 30, // 7:30 AM IST
    );

    print("  >> raw scheduledTime: $scheduledTime");

    if (scheduledTime.isBefore(now)) {
      if (scheduledTime.year == now.year &&
          scheduledTime.month == now.month &&
          scheduledTime.day == now.day) {
        scheduledTime = now.add(const Duration(seconds: 5));
        print("  >> ADJUSTED TO TODAY: $scheduledTime");
      } else {
        print("  >> IGNORING PAST SCHEDULE");
        continue;
      }
    }

    print("  >> FINAL SCHEDULE VERDICT: $scheduledTime");
    print("");
  }
}
