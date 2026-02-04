import 'package:http/http.dart' as http;

Future<void> main() async {
  final urls = [
    "https://smart-desk-backend.vercel.app/holidays.json",
    "https://smartdesk-backend.netlify.app/AcademicCalendar1.json",
    "https://smartdesk-backend.netlify.app/holidays.json"
  ];

  for (final url in urls) {
    print("Testing $url...");
    try {
      final response = await http.get(Uri.parse(url));
      print("Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("Success! Body length: ${response.body.length}");
      } else {
        print("Failed with status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching $url: $e");
    }
    print("-------------------");
  }
}
