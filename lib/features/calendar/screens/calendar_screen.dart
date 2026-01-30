import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'academic_calendar_screen.dart';

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late Future<List<dynamic>> _holidayFuture = Future.value([]);
  bool offline = false;
  int? _joiningYear; // Added to store the year from settings

  static const String cacheKey = "holiday_cache_v1";

  @override
  void initState() {
    super.initState();
    _checkInternet(isInitialLoad: true);
    _loadUserSettings(); // Load the joining year on start
  }

  // Load joining year from SharedPreferences
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _joiningYear = prefs.getInt('joining_year');
    });
  }

  // Logic: (CurrentYear - JoiningYear) + 1 if Month >= September
  int _calculateAcademicYear(int joiningYear) {
    final now = DateTime.now();
    int yearDiff = now.year - joiningYear;

    // If we are in September (9) or later, the academic year has incremented
    if (now.month >= 9) {
      yearDiff += 1;
    }

    // Safety: If joined this year and it's before September, it's 1st year (0 + 1 logic needed)
    // But usually, if they join in 2024, they are 1st year immediately.
    // Based on your plan: (2024-2024) + (Month >= 9 ? 1 : 0).
    // We'll ensure it doesn't return 0.
    if (yearDiff <= 0) return 1;
    return yearDiff;
  }

  // Helper to get 1st, 2nd, 3rd, 4th suffix
  String _getOrdinal(int year) {
    if (year == 1) return "1st";
    if (year == 2) return "2nd";
    if (year == 3) return "3rd";
    return "${year}th";
  }

  Future<void> _checkInternet({bool isInitialLoad = false}) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      setState(() {
        offline = true;
        if (isInitialLoad) {
          _holidayFuture = _loadFromCacheOrError();
        }
      });
    } else {
      setState(() {
        offline = false;
        _holidayFuture = fetchHolidays();
      });
    }
  }

  Future<List<dynamic>> _loadFromCacheOrError() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(cacheKey)) {
      final cachedJson = prefs.getString(cacheKey)!;
      return jsonDecode(cachedJson);
    } else {
      return Future.error("Offline");
    }
  }

  Future<List<dynamic>> fetchHolidays() async {
    const url = "https://smart-desk-backend.vercel.app/holidays.json";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(cacheKey, response.body);
        return jsonDecode(response.body);
      } else {
        return _loadFromCacheOrError();
      }
    } catch (_) {
      return _loadFromCacheOrError();
    }
  }

  Future<void> _refreshPage() async {
    await _checkInternet();
    await _loadUserSettings(); // Refresh the joining year as well
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SOA Holidays List"),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: FutureBuilder<List<dynamic>>(
          future: _holidayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !offline && snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && snapshot.data == null) {
              return _buildOfflinePlaceholder();
            }
            final holidays = snapshot.data ?? [];
            if (holidays.isEmpty && snapshot.hasError) {
              return _buildOfflinePlaceholder();
            }
            return _buildHolidayTable(holidays);
          },
        ),
      ),
    );
  }

  Widget _buildOfflinePlaceholder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text("No data available offline."),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHolidayTable(List<dynamic> holidays) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    final headerBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final headerTextColor = isDark ? Colors.white : Colors.black;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Table(
            border: TableBorder.all(color: borderColor),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: headerBgColor),
                children: [
                  _headerCell("Sl. No", headerTextColor),
                  _headerCell("Name of Festive Days", headerTextColor),
                  _headerCell("Date", headerTextColor),
                  _headerCell("Day", headerTextColor),
                ],
              ),
              ...holidays.map((holiday) => TableRow(
                children: [
                  _dataCell(holiday["sl"] ?? ""),
                  _dataCell(holiday["name"] ?? ""),
                  _dataCell(holiday["date"] ?? ""),
                  _dataCell(holiday["day"] ?? ""),
                ],
              )),
            ],
          ),
          const SizedBox(height: 25),

          // --- DYNAMIC BUTTON SECTION ---
          if (_joiningYear != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("Academic Calendar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            _buildDynamicButton(),
            const SizedBox(height: 25),
          ],

          // --- MANUAL SELECT SECTION ---
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text("All Academic Calendars", style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildYearButton("1st", "https://smartdesk-backend.netlify.app/AcademicCalendar1.json"),
              _buildYearButton("2nd", "https://smartdesk-backend.netlify.app/AcademicCalendar2.json"),
              _buildYearButton("3rd", "https://smartdesk-backend.netlify.app/AcademicCalendar3.json"),
              _buildYearButton("4th", "https://smartdesk-backend.netlify.app/AcademicCalendar4.json"),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _headerCell(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _dataCell(String text) {
    return Padding(padding: const EdgeInsets.all(8), child: Text(text));
  }

  // The Dynamic Button implementation
  Widget _buildDynamicButton() {
    final year = _calculateAcademicYear(_joiningYear!);
    // We cap it at 4 since the backend likely only has 4 years
    final displayYear = year > 4 ? 4 : year;
    final ordinal = _getOrdinal(displayYear);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.auto_awesome),
          label: Text("View Your $ordinal Year Academic Calendar",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AcademicCalendarPage(
                  title: "$ordinal Year Academic Calendar",
                  url: "https://smartdesk-backend.netlify.app/AcademicCalendar$displayYear.json",
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildYearButton(String text, String url) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AcademicCalendarPage(
                  title: "Academic Calendar for $text year",
                  url: url,
                ),
              ),
            );
          },
          child: Text(text),
        ),
      ),
    );
  }
}