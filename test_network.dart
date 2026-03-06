import 'package:http/http.dart' as http;
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  
  final urls = [
    "https://smart-desk-backend.vercel.app/curriculum.json",
    "https://smart-desk-backend.vercel.app/holidays.json",
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
