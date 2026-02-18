import 'dart:convert';
import 'package:http/http.dart' as http;

class TimetableApiService {
  static const String _baseUrl =
      'https://smartdesk-backend-timetable.imtiyazallam07.workers.dev';

  /// Fetches the list of available timetables grouped by year
  /// Returns a `Map<String, List<String>>` where keys are years (e.g., "2024")
  /// and values are lists of section codes (e.g., ["24E1P2", "24E1O2"])
  static Future<Map<String, List<String>>> fetchAvailableTimetables() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/available_timetable.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, List<String>> result = {};

        data.forEach((year, sections) {
          if (sections is List) {
            result[year] = List<String>.from(sections);
          }
        });

        return result;
      } else {
        throw Exception('Failed to load timetables: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching available timetables: $e');
    }
  }

  /// Fetches a specific timetable by section code
  /// Returns a `Map<String, List<Map<String, dynamic>>>` where keys are day numbers (1-6)
  /// and values are lists of time slots with format: {n: subject, a: start hour, b: end hour}
  static Future<Map<String, List<Map<String, dynamic>>>>
      fetchTimetableBySection(String section) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$section.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, List<Map<String, dynamic>>> result = {};

        data.forEach((day, slots) {
          if (slots is List) {
            result[day] = List<Map<String, dynamic>>.from(
              slots.map((slot) => Map<String, dynamic>.from(slot)),
            );
          }
        });

        return result;
      } else if (response.statusCode == 404) {
        throw Exception('Timetable not found for section: $section');
      } else {
        throw Exception('Failed to load timetable: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching timetable for $section: $e');
    }
  }
}
