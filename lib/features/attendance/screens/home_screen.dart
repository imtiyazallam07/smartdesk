import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/timetable_provider.dart';
import '../providers/subject_provider.dart';
import 'day_attendance_screen.dart';
import 'timetable_setup_screen.dart';
import 'subject_management_screen.dart';
import 'subject_attendance_graph_screen.dart';
import '../services/holiday_service.dart';
import '../../../shared/responsive_utils.dart';

// ── Colour palette (mirrors home dashboard) ──────────────────────────────────
const _kGreen        = Color(0xFF22C55E);
const _kTextPrimary  = Color(0xFFE5E7EB);
const _kTextSecondary = Color(0xFF9CA3AF);

// Subject strip colours (one per subject, cycling)
const List<Color> _kSubjectColors = [
  Color(0xFF6366F1),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
];

Color _colorForPercentage(double pct) {
  if (pct >= 80) return Colors.green;
  if (pct >= 75) return Colors.orange;
  if (pct >= 60) return Colors.deepOrange;
  return Colors.red;
}

// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => _loadData());
    _loadNextWorkingDay();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNextWorkingDay() async {
    await HolidayService().getNextWorkingDay();
    if (mounted) setState(() {});
  }

  void _loadData() {
    Provider.of<AttendanceProvider>(context, listen: false).loadAll();
    Provider.of<TimetableProvider>(context, listen: false).init();
    Provider.of<SubjectProvider>(context, listen: false).loadSubjects();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.book_outlined),
            tooltip: 'Subjects',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SubjectManagementScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.schedule_rounded),
            tooltip: 'Timetable Setup',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TimetableSetupScreen())),
          ),
        ],
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // ── Calendar ────────────────────────────────────────────────
              _buildCalendar(provider, isDark),

              // ── Tab Bar ─────────────────────────────────────────────────
              _buildTabBar(isDark),

              // ── Tab content ─────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0 – Total (all time)
                    _buildSubjectList(
                      context: context,
                      isDark: isDark,
                      stats: provider.getAllSubjectStats(),
                      emptyMessage: 'No attendance recorded yet.',
                    ),
                    // Tab 1 – This Month
                    _buildSubjectList(
                      context: context,
                      isDark: isDark,
                      stats: provider.getMonthlySubjectStats(
                          _focusedDay.year, _focusedDay.month),
                      emptyMessage: 'No attendance data for this month.',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Tab bar (pill style, mirrors dashboard) ─────────────────────────────────
  Widget _buildTabBar(bool isDark) {
    final bg = isDark
        ? const Color(0xFF1F2937)
        : Colors.grey.shade200;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: rw(context, 16), vertical: rw(context, 6)),
      padding: EdgeInsets.all(rw(context, 3)),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(rw(context, 14))),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(rw(context, 11)),
          color: _kGreen,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? _kTextSecondary : Colors.black54,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: rw(context, 14)),
        tabs: const [
          Tab(text: 'Total'),
          Tab(text: 'This Month'),
        ],
      ),
    );
  }

  // ── Calendar ─────────────────────────────────────────────────────────────────
  Widget _buildCalendar(AttendanceProvider provider, bool isDark) {
    return Container(
      margin: EdgeInsets.fromLTRB(rw(context, 16), rw(context, 8), rw(context, 16), rw(context, 4)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(rw(context, 20)),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.06))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2030),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        weekendDays: const [DateTime.sunday],
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: rw(context, 15),
            color: isDark ? _kTextPrimary : Colors.black87,
          ),
          leftChevronIcon: Icon(Icons.chevron_left,
              color: isDark ? _kTextSecondary : Colors.black54),
          rightChevronIcon: Icon(Icons.chevron_right,
              color: isDark ? _kTextSecondary : Colors.black54),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: isDark ? _kTextSecondary : Colors.black54,
              fontSize: rw(context, 12),
              fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(
              color: isDark ? _kTextSecondary : Colors.black54,
              fontSize: rw(context, 12),
              fontWeight: FontWeight.w600),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            // softer ring in dark so it doesn't glow
            color: _kGreen.withValues(alpha: isDark ? 0.15 : 0.22),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _kGreen),
          selectedDecoration: BoxDecoration(
            color: isDark ? const Color(0xFF16A34A) : _kGreen,
            shape: BoxShape.circle,
          ),
          selectedTextStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          defaultTextStyle:
              TextStyle(color: isDark ? _kTextPrimary : Colors.black87),
          weekendTextStyle:
              TextStyle(color: isDark ? _kTextPrimary : Colors.black87),
          outsideTextStyle: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          final provider =
              Provider.of<AttendanceProvider>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DayAttendanceScreen(date: selectedDay)),
          ).then((_) => provider.loadAll());
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
          Provider.of<AttendanceProvider>(context, listen: false)
              .loadMonth(focusedDay.year, focusedDay.month);
        },
        eventLoader: (day) {
          final att = provider.getAttendance(day);
          return (att != null && att.status != AttendanceStatus.notMarked)
              ? [att]
              : [];
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            final att = events.first as DailyAttendance;
            Color color;
            switch (att.status) {
              case AttendanceStatus.present:
                color = isDark ? const Color(0xFF4ADE80) : _kGreen;
                break;
              case AttendanceStatus.absent:
                color = isDark ? const Color(0xFFF87171) : Colors.red;
                break;
              case AttendanceStatus.partial:
                color = isDark ? const Color(0xFFFBBF24) : Colors.orange;
                break;
              case AttendanceStatus.holiday:
                color = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
                break;
              default:
                return null;
            }
            return Positioned(
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Subject stats list ────────────────────────────────────────────────────────
  Widget _buildSubjectList({
    required BuildContext context,
    required bool isDark,
    required Map<String, Map<String, dynamic>> stats,
    required String emptyMessage,
  }) {
    if (stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 44, color: _kGreen),
            ),
            const SizedBox(height: 14),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? _kTextPrimary : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mark attendance using the calendar above.',
              style: TextStyle(fontSize: 13, color: _kTextSecondary),
            ),
          ],
        ),
      );
    }

    final subjectNames = stats.keys.toList();
    // Always fetch all-time stats for the graph, regardless of active tab
    final allTimeStats =
        Provider.of<AttendanceProvider>(context, listen: false)
            .getAllSubjectStats();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      itemCount: subjectNames.length,
      itemBuilder: (context, index) {
        final subject = subjectNames[index];
        final data    = stats[subject]!;
        final double pct     = data['percentage'];
        final int    present = data['present'];
        final int    total   = data['total'];
        final int    absent  = total - present;
        final Color  color   = _colorForPercentage(pct);
        final Color  strip   = _kSubjectColors[index % _kSubjectColors.length];

        final classesNeeded = pct >= 75 ? 0 : (3 * total - 4 * present).ceil();

        // All-time values for the graph screen
        final allData    = allTimeStats[subject];
        final double allPct     = allData?['percentage'] ?? pct;
        final int    allPresent = allData?['present']    ?? present;
        final int    allTotal   = allData?['total']      ?? total;

        return _SubjectStatCard(
          isDark: isDark,
          subject: subject,
          pct: pct,
          present: present,
          absent: absent,
          total: total,
          color: color,
          strip: strip,
          classesNeeded: classesNeeded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectAttendanceGraphScreen(
                subjectName: subject,
                subjectColor: strip,
                currentPct: allPct,
                present: allPresent,
                total: allTotal,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject stat card — mirrors the home dashboard attendance row style
// ─────────────────────────────────────────────────────────────────────────────
class _SubjectStatCard extends StatelessWidget {
  final bool  isDark;
  final String subject;
  final double pct;
  final int    present, absent, total;
  final Color  color, strip;
  final int    classesNeeded;
  final VoidCallback onTap;

  const _SubjectStatCard({
    required this.isDark,
    required this.subject,
    required this.pct,
    required this.present,
    required this.absent,
    required this.total,
    required this.color,
    required this.strip,
    required this.classesNeeded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final donutSize = rw(context, 68);
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: EdgeInsets.symmetric(horizontal: rw(context, 16), vertical: rw(context, 6)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)]
              : [color.withValues(alpha: 0.07), Colors.white],
        ),
        borderRadius: BorderRadius.circular(rw(context, 18)),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.18 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(rw(context, 14)),
        child: Row(
          children: [
            // ── Donut chart ─────────────────────────────────
            SizedBox(
              width: donutSize,
              height: donutSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(PieChartData(
                    sections: [
                      PieChartSectionData(
                          value: present.toDouble(),
                          color: color,
                          radius: rw(context, 10),
                          showTitle: false),
                      PieChartSectionData(
                          value: absent.toDouble(),
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          radius: rw(context, 10),
                          showTitle: false),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: rw(context, 24),
                    startDegreeOffset: -90,
                  )),
                  Text(
                    '${pct.toInt()}%',
                    style: TextStyle(
                        fontSize: rw(context, 13), fontWeight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            ),
            SizedBox(width: rw(context, 14)),
            // ── Details ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject name + status icon
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: rw(context, 14),
                            color: isDark ? _kTextPrimary : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: ri(context, 16),
                        color: isDark ? _kTextSecondary : Colors.black38,
                      ),
                      SizedBox(width: rw(context, 4)),
                      Container(
                        padding: EdgeInsets.all(rw(context, 6)),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.10 : 0.14),
                            shape: BoxShape.circle),
                        child: Icon(
                          pct < 60
                              ? Icons.priority_high
                              : pct < 75
                                  ? Icons.trending_down
                                  : Icons.check_rounded,
                          size: ri(context, 16),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: rw(context, 6)),
                  // Linear progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      color: color,
                      minHeight: 5,
                    ),
                  ),
                  SizedBox(height: rw(context, 6)),
                  // Present / Absent counts + classes hint
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: ri(context, 13),
                          color: isDark ? const Color(0xFF4ADE80) : Colors.green.shade600),
                      SizedBox(width: rw(context, 3)),
                      Text('$present',
                          style: TextStyle(
                              fontSize: rw(context, 11),
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF4ADE80) : Colors.green.shade600)),
                      SizedBox(width: rw(context, 10)),
                      Icon(Icons.cancel_outlined,
                          size: ri(context, 13),
                          color: isDark ? const Color(0xFFF87171) : Colors.red.shade500),
                      SizedBox(width: rw(context, 3)),
                      Text('$absent',
                          style: TextStyle(
                              fontSize: rw(context, 11),
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF87171) : Colors.red.shade500)),
                      const Spacer(),
                      Text(
                        'of $total',
                        style: TextStyle(
                            fontSize: rw(context, 11),
                            color: isDark ? _kTextSecondary : Colors.black45),
                      ),
                    ],
                  ),
                  if (classesNeeded > 0) ...[
                    SizedBox(height: rw(context, 4)),
                    Text(
                      'Need $classesNeeded more class${classesNeeded > 1 ? 'es' : ''} for 75%',
                      style: TextStyle(
                          fontSize: rw(context, 10),
                          color: color,
                          fontWeight: FontWeight.w500),
                    ),
                  ] else ...[
                    SizedBox(height: rw(context, 4)),
                    Text(
                      'Above 75% ✓',
                      style: TextStyle(
                          fontSize: rw(context, 10),
                          color: isDark ? const Color(0xFF4ADE80) : Colors.green.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
