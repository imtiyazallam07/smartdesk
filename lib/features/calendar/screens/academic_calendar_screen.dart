import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- 1. Data Model ---
class CalendarEvent {
  final String day;
  final String event;

  CalendarEvent({required this.day, required this.event});

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      day: json['day'] ?? '',
      event: json['event'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'event': event,
  };
}

class AcademicCalendarPage extends StatefulWidget {
  final String title;
  final String url;

  const AcademicCalendarPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  late Future<List<CalendarEvent>> _calendarFuture = Future.value([]);

  bool offline = false;
  late final String cacheKey;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    cacheKey = "academic_calendar_${widget.url.hashCode}";
    _checkConnection(isInitialLoad: true);
  }

  // -------------------------------------------------------------
  // LOGIC: CACHE & CONNECTIVITY
  // -------------------------------------------------------------

  Future<List<CalendarEvent>?> loadCachedCalendar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;

    final List<dynamic> decoded = jsonDecode(raw);
    return decoded.map((json) => CalendarEvent.fromJson(json)).toList();
  }

  Future<void> saveCachedCalendar(List<CalendarEvent> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(data.map((e) => e.toJson()).toList());
    await prefs.setString(cacheKey, raw);
  }

  Future<void> _checkConnection({bool isInitialLoad = false}) async {
    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      setState(() {
        offline = true;
        if (isInitialLoad) {
          _calendarFuture = loadCachedCalendar().then((cached) {
            if (cached != null) return cached;
            throw Exception("Offline. No cached data.");
          });
        }
      });
    } else {
      setState(() {
        offline = false;
        _calendarFuture = fetchCalendarData();
      });
    }
  }

  Future<void> _refreshPage() async {
    await _checkConnection();
  }

  Future<List<CalendarEvent>> fetchCalendarData() async {
    try {
      final response = await http.get(Uri.parse(widget.url));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final events =
        jsonList.map((json) => CalendarEvent.fromJson(json)).toList();

        await saveCachedCalendar(events);
        return events;
      } else {
        throw Exception("Server Error ${response.statusCode}");
      }
    } catch (e) {
      final cached = await loadCachedCalendar();
      if (cached != null) return cached;
      throw Exception("Failed to load data & no cache available");
    }
  }

  // -------------------------------------------------------------
  // UI BUILDER
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // We use Theme.of(context) to access colors automatically
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (offline)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.wifi_off, color: Colors.red),
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: FutureBuilder<List<CalendarEvent>>(
          future: _calendarFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildOfflinePlaceholder(snapshot.error.toString());
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return _buildPrettyList(snapshot.data!);
            }
            return const Center(child: Text("No events found"));
          },
        ),
      ),
    );
  }

  Widget _buildOfflinePlaceholder(String error) {
    return ListView(
      padding: const EdgeInsets.only(top: 60),
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              "You are offline",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                "We couldn't reach the server and there is no cached data available.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _refreshPage,
              child: const Text("Retry Connection"),
            )
          ],
        )
      ],
    );
  }

  Widget _buildPrettyList(List<CalendarEvent> events) {
    List<Widget> listWidgets = [];

    listWidgets
        .add(const SemesterHeader(title: "Odd Semester", color: Colors.indigo));

    for (int i = 0; i < events.length; i++) {
      final event = events[i];

      if (event.event.toLowerCase().contains("commencement of even semester")) {
        listWidgets.add(const SizedBox(height: 20));
        listWidgets.add(
            const SemesterHeader(title: "Even Semester", color: Colors.teal));
      }

      listWidgets.add(
        EventCard(
          event: event,
          index: i,
          isSelected: i == _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = (_selectedIndex == index) ? null : index;
            });
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: listWidgets,
    );
  }
}

// --- 3. Custom UI Components ---

class SemesterHeader extends StatelessWidget {
  final String title;
  final Color color;

  const SemesterHeader({super.key, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    // Check brightness to adjust text color
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              // Dynamic color based on theme
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final int index;
  final bool isSelected;
  final void Function(int) onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  // Updated Logic to support Dark Mode colors
  Map<String, dynamic> _getEventStyle(String title, bool isDark) {
    title = title.toLowerCase();

    // Helper to get background color (Pastel for Light, Translucent for Dark)
    Color getBg(Color color) => isDark ? color.withValues(alpha: 0.15) : color.withAlpha(30); // ~shade50 equivalent

    if (title.contains("quiz")) {
      return {'icon': Icons.edit_note, 'color': Colors.orange, 'bg': getBg(Colors.orange)};
    } else if (title.contains("exam")) {
      return {'icon': Icons.school, 'color': Colors.redAccent, 'bg': getBg(Colors.red)};
    } else if (title.contains("break") || title.contains("vacation")) {
      return {'icon': Icons.beach_access, 'color': Colors.green, 'bg': getBg(Colors.green)};
    } else if (title.contains("revision")) {
      return {'icon': Icons.refresh, 'color': Colors.blue, 'bg': getBg(Colors.blue)};
    } else if (title.contains("commencement") || title.contains("class")) {
      return {'icon': Icons.class_, 'color': Colors.indigo, 'bg': getBg(Colors.indigo)};
    }

    // Default
    return {
      'icon': Icons.event,
      'color': isDark ? Colors.grey.shade400 : Colors.grey,
      'bg': isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100
    };
  }

  int? _calculateDaysLeft(String dateString) {
    final parts = dateString.split(' to ');
    final targetDateStr = parts[0];

    try {
      final dateParts = targetDateStr.split('/');
      if (dateParts.length != 3) return null;

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final targetDate = DateTime(year, month, day);
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      if (targetDate.isBefore(todayNormalized)) {
        return -1;
      }

      return targetDate.difference(todayNormalized).inDays;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _getEventStyle(event.event, isDark);
    final daysLeft = _calculateDaysLeft(event.day);

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          // Dynamic Card Color
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: style['color'], width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), // Darker shadow for dark mode
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Box
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: style['bg'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(style['icon'], color: style['color'], size: 24),
                  ),
                  const SizedBox(width: 16),
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.event,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            // Dynamic Text Color
                            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 14,
                                color: isDark ? Colors.grey[400] : Colors.grey[500]
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.day,
                                style: TextStyle(
                                  fontSize: 13,
                                  // Dynamic Subtitle Color
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (isSelected && daysLeft != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        // Dynamic Chip Background
                        color: daysLeft >= 0
                            ? (isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.indigo.shade50)
                            : (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        daysLeft > 0
                            ? '$daysLeft days left'
                            : (daysLeft == 0 ? 'Today' : 'Event passed'),
                        style: TextStyle(
                          // Dynamic Chip Text Color
                          color: daysLeft >= 0
                              ? (isDark ? Colors.indigo.shade200 : Colors.indigo.shade700)
                              : (isDark ? Colors.red.shade200 : Colors.red.shade700),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
