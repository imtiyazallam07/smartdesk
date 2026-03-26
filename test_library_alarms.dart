import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:smartdesk/features/library/models/book.dart';
import 'package:smartdesk/features/library/screens/library_screen.dart';

void main() async {
  print("Initializing timezones...");
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Emulate KST/IST

  final book = Book(
    id: 12345,
    title: "The Great Gatsby",
    returnDate: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
    isReturned: 0,
  );

  print("Calling scheduleBookNotifications...");
  await LibraryNotificationService.scheduleBookNotifications(book);
  print("Finished.");
}
