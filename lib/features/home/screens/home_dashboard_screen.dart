import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/providers/timetable_provider.dart';
import '../../attendance/models/timetable.dart';
import '../../attendance/models/attendance.dart';
import '../../attendance/screens/home_screen.dart';
import '../../attendance/screens/timetable_screen.dart';
import '../../todo/services/todo_db_helper.dart';
import '../../todo/models/todo_model.dart';
import '../../todo/screens/todo_home_screen.dart';
import '../../library/services/library_database_helper.dart';
import '../../library/models/book.dart';
import '../../library/screens/library_screen.dart' show LibraryTrackerScreen;
import '../../../widgets/dashboard_card_widget.dart';
import '../../../shared/models/feature.dart';
import '../../settings/providers/home_widget_provider.dart';
import 'package:home_widget/home_widget.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import '../../../services/widget_update_service.dart';
import '../../../shared/responsive_utils.dart';
// ──────────────────────────────────────────────
// Colour palette constants
// ──────────────────────────────────────────────
const _kGreen = Color(0xFF22C55E);
const _kWarning = Color(0xFFF59E0B);
const _kTextPrimary = Color(0xFFE5E7EB);
const _kTextSecondary = Color(0xFF9CA3AF);
const _kCardDark = Color(0xFF111827);

// Subject colour strip palette
const List<Color> _kSubjectColors = [
  Color(0xFF6366F1), // indigo
  Color(0xFF22C55E), // green
  Color(0xFF3B82F6), // blue
  Color(0xFFF59E0B), // amber
  Color(0xFFEC4899), // pink
  Color(0xFF8B5CF6), // violet
  Color(0xFFEF4444), // red
];

// ──────────────────────────────────────────────
// Widget
// ──────────────────────────────────────────────
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with TickerProviderStateMixin {
  List<RecurringTask> _todayRecurringTasks = [];
  List<OneTimeTask> _upcomingTasks = [];
  List<Book> _upcomingBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initHomeWidgetListener();
  }

  void _initHomeWidgetListener() {
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) _handleWidgetRoute(uri);
    });

    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) _handleWidgetRoute(uri);
    });
  }

  void _handleWidgetRoute(Uri uri) {
    if (!mounted) return;
    final host = uri.host; 
    if (host == 'tasks') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoHomeScreen()));
    } else if (host == 'books') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryTrackerScreen()));
    } else if (host == 'timetable') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    }
  }

  Future<void> _initializeProviders() async {
    final timetableProvider =
        Provider.of<TimetableProvider>(context, listen: false);
    final attendanceProvider =
        Provider.of<AttendanceProvider>(context, listen: false);
    await timetableProvider.refreshTimetable();
    await attendanceProvider.loadAll();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await _initializeProviders();

    final allRecurringTasks =
        await TodoDatabaseHelper.instance.getRecurringTasks();
    final todayTasks = _filterTodayRecurringTasks(allRecurringTasks);

    final allOneTimeTasks =
        await TodoDatabaseHelper.instance.getOneTimeTasks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingTasks = allOneTimeTasks.where((task) {
      if (task.isCompleted) return false;
      if (task.deadline == null) return false;
      final deadlineDate = DateTime(
          task.deadline!.year, task.deadline!.month, task.deadline!.day);
      final daysUntilDeadline = deadlineDate.difference(today).inDays;
      return daysUntilDeadline >= 0 && daysUntilDeadline < 3;
    }).toList();

    final allBooks = await LibraryDatabaseHelper.instance.readAllBooks();
    var upcomingBooks = allBooks.where((book) {
      if (book.isReturned == 1) return false;
      try {
        DateTime.parse(book.returnDate);
        return true;
      } catch (_) {
        return false;
      }
    }).toList();
    
    upcomingBooks.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.returnDate);
        final dateB = DateTime.parse(b.returnDate);
        return dateA.compareTo(dateB);
      } catch (_) {
        return 0;
      }
    });

    if (mounted) {
      setState(() {
        _todayRecurringTasks = todayTasks;
        _upcomingTasks = upcomingTasks;
        _upcomingBooks = upcomingBooks;
        _isLoading = false;
      });
    }
    
    // Update native Android widgets
    _updateHomeWidgets();
  }

  Future<void> _updateHomeWidgets() async {
    await WidgetUpdateService.updateAllWidgets();
  }

  List<RecurringTask> _filterTodayRecurringTasks(List<RecurringTask> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOfWeek = now.weekday;

    return tasks.where((task) {
      if (!task.isActive) return false;
      if (task.fromDate != null) {
        final fromDate = DateTime(
            task.fromDate!.year, task.fromDate!.month, task.fromDate!.day);
        if (today.isBefore(fromDate)) return false;
      }
      if (task.toDate != null) {
        final toDate =
            DateTime(task.toDate!.year, task.toDate!.month, task.toDate!.day);
        if (today.isAfter(toDate)) return false;
      }
      if (task.repeatType == 0) {
        return dayOfWeek >= 1 && dayOfWeek <= 6;
      } else if (task.repeatType == 1) {
        if (task.repeatDays == null || task.repeatDays!.isEmpty) return false;
        try {
          final days =
              task.repeatDays!.split(',').map((s) => int.parse(s.trim())).toList();
          return days.contains(dayOfWeek);
        } catch (_) {
          return false;
        }
      } else if (task.repeatType == 2) {
        if (task.intervalDays == null || task.fromDate == null) return false;
        final fromDate = DateTime(
            task.fromDate!.year, task.fromDate!.month, task.fromDate!.day);
        final daysSinceStart = today.difference(fromDate).inDays;
        return daysSinceStart >= 0 &&
            daysSinceStart % task.intervalDays! == 0;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _isLoading
        ? Center(
            child: CircularProgressIndicator(color: _kGreen),
          )
        : RefreshIndicator(
            color: _kGreen,
            onRefresh: _loadData,
            child: Consumer<HomeWidgetProvider>(
              builder: (context, wPref, _) {
                return ListView(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: MediaQuery.of(context).padding.bottom + 100,
                  ),
                  children: [
                    _buildSectionLabel('Quick Actions', isDark),
                    const SizedBox(height: 8),
                    _buildQuickActions(context),
                    const SizedBox(height: 8),
                    _buildAttendanceWidget(),
                    if (wPref.showTimetable) _buildTodayTimetableWidget(),
                    if (wPref.showTasks) _buildRecurringTasksWidget(),
                    if (wPref.showTasks) _buildUpcomingTasksWidget(),
                    if (wPref.showBooks) _buildLibraryBooksWidget(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(context, 20)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: rw(context, 13),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: isDark ? _kTextSecondary : Colors.black45,
        ),
      ),
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final List<Feature> quickFeatures = [
      Feature(
        title: 'Tasks & Reminder',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFFE91E63),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TodoHomeScreen())),
      ),
      Feature(
        title: 'Attendance Tracker',
        icon: Icons.calendar_today_rounded,
        color: _kGreen,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => HomeScreen())),
      ),
      Feature(
        title: 'Library Record',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFF99014),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => LibraryTrackerScreen())),
      ),
      Feature(
        title: 'Timetable',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF3399FF),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimetableScreen())),
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = Responsive.isCompact(context);
    final cardRadius = rw(context, 20);
    final iconBoxSize = rw(context, 40);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(context, 16)),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: quickFeatures.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: rw(context, 12),
          mainAxisSpacing: rw(context, 12),
          childAspectRatio: compact ? 2.3 : 2.6,
        ),
        itemBuilder: (context, index) {
          final feature = quickFeatures[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: feature.onTap,
              borderRadius: BorderRadius.circular(cardRadius),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: rw(context, 14), vertical: rw(context, 10)),
                decoration: BoxDecoration(
                  color: isDark ? _kCardDark : Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      decoration: BoxDecoration(
                        color: feature.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(rw(context, 12)),
                      ),
                      child:
                          Icon(feature.icon, color: feature.color, size: ri(context, 22)),
                    ),
                    SizedBox(width: rw(context, 10)),
                    Expanded(
                      child: Text(
                        feature.title,
                        style: TextStyle(
                          fontSize: rw(context, 13),
                          fontWeight: FontWeight.w600,
                          color: isDark ? _kTextPrimary : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── ATTENDANCE HERO CARD ──────────────────────
  Widget _buildAttendanceWidget() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
        final stats = attendanceProvider.getAllSubjectStats();

        final lowAttendanceSubjects = stats.entries
            .where((entry) => entry.value['percentage'] < 80.0)
            .toList()
          ..sort((a, b) => (a.value['percentage'] as double)
              .compareTo(b.value['percentage'] as double));

        final isDark = Theme.of(context).brightness == Brightness.dark;

        // All subjects good!
        if (lowAttendanceSubjects.isEmpty) {
          return _AttendanceHeroCard(isDark: isDark);
        }

        // Low attendance list
        return DashboardCard(
          title: 'Low Attendance Alert (Total)',
          icon: Icons.warning_amber_rounded,
          accentColor: Colors.red,
          onViewAll: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const HomeScreen())),
          content: Column(
            children: lowAttendanceSubjects.map((entry) {
              final subject = entry.key;
              final percentage = entry.value['percentage'] as double;
              final present = entry.value['present'] as int;
              final total = entry.value['total'] as int;
              final absent = total - present;
              final color = _getColorForPercentage(percentage);

              final donutSize = rw(context, 64);
              return Container(
                margin: EdgeInsets.symmetric(vertical: rw(context, 6)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            color.withValues(alpha: 0.15),
                            color.withValues(alpha: 0.05),
                          ]
                        : [
                            color.withValues(alpha: 0.08),
                            Colors.white,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(rw(context, 14)),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(rw(context, 14)),
                  child: Row(
                    children: [
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
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade200,
                                    radius: rw(context, 10),
                                    showTitle: false),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: rw(context, 22),
                              startDegreeOffset: -90,
                            )),
                            Text(
                              '${percentage.toInt()}%',
                              style: TextStyle(
                                  fontSize: rw(context, 13),
                                  fontWeight: FontWeight.bold,
                                  color: color),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: rw(context, 14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: rw(context, 14),
                                    color: isDark
                                        ? _kTextPrimary
                                        : Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            SizedBox(height: rw(context, 6)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade200,
                                color: color,
                                minHeight: 5,
                              ),
                            ),
                            SizedBox(height: rw(context, 5)),
                            Row(children: [
                              Icon(Icons.check_circle_outline,
                                  size: ri(context, 13),
                                  color: Colors.green.shade500),
                              SizedBox(width: rw(context, 3)),
                              Text('$present',
                                  style: TextStyle(
                                      fontSize: rw(context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade500)),
                              SizedBox(width: rw(context, 10)),
                              Icon(Icons.cancel_outlined,
                                  size: ri(context, 13), color: Colors.red.shade400),
                              SizedBox(width: rw(context, 3)),
                              Text('$absent',
                                  style: TextStyle(
                                      fontSize: rw(context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade400)),
                              const Spacer(),
                              Text('of $total',
                                  style: TextStyle(
                                      fontSize: rw(context, 11), color: _kTextSecondary)),
                            ]),
                          ],
                        ),
                      ),
                      SizedBox(width: rw(context, 6)),
                      Container(
                        padding: EdgeInsets.all(rw(context, 7)),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle),
                        child: Icon(
                            percentage < 60
                                ? Icons.priority_high
                                : Icons.trending_down,
                            size: ri(context, 18),
                            color: color),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 75) return Colors.orange;
    if (percentage >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  // ── TODAY'S CLASSES (TIMELINE) ─────────────────
  Widget _buildTodayTimetableWidget() {
    return Consumer<TimetableProvider>(
      builder: (context, timetableProvider, child) {
        final now = DateTime.now();
        final dayOfWeek = now.weekday;
        final schedule = timetableProvider.getScheduleForDay(dayOfWeek);
        final attendanceProvider =
            Provider.of<AttendanceProvider>(context, listen: false);

        return DashboardCard(
          title: "Today's Classes",
          icon: Icons.schedule_rounded,
          accentColor: const Color(0xFF6366F1),
          onViewAll: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TimetableScreen())),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              schedule == null || schedule.slots.isEmpty
                  ? _buildEmptyClasses()
                  : Column(
                      children: schedule.slots
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => _TimelineSlotItem(
                                slot: e.value,
                                index: e.key,
                                now: now,
                                attendanceProvider: attendanceProvider,
                                timetableProvider: timetableProvider,
                                isLast: e.key == math.min(schedule.slots.length, 5) - 1,
                                todayDate: DateTime(now.year, now.month, now.day),
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HomeScreen())),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Mark Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyClasses() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.celebration_outlined, size: 44, color: _kTextSecondary),
            SizedBox(height: 10),
            Text('No classes today!',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextSecondary)),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Enjoy your free time ',
                    style: TextStyle(fontSize: 13, color: _kTextSecondary)),
                Icon(Icons.auto_awesome, size: 14, color: _kTextSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── TODAY'S REMINDERS ─────────────────────────
  Widget _buildRecurringTasksWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      title: "Today's Reminders",
      icon: Icons.event_repeat,
      accentColor: const Color(0xFF3B82F6),
      onViewAll: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TodoHomeScreen())),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _todayRecurringTasks.isEmpty
              ? _buildRemindersEmptyState(isDark)
              : Column(
                  children: _todayRecurringTasks.take(3).map((task) {
                    return _buildStyledReminderTile(task, isDark);
                  }).toList(),
                ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TodoHomeScreen())),
              icon: const Icon(Icons.task_alt_outlined, size: 16),
              label: const Text('View all tasks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_outlined,
                  size: 44, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(height: 14),
            Text(
              'Nothing scheduled for today',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? _kTextPrimary : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enjoy your free time or add a reminder',
              style: TextStyle(fontSize: 13, color: _kTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TodoHomeScreen())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Reminder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledReminderTile(RecurringTask task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Color(0xFF3B82F6), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(task.title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? _kTextPrimary : Colors.black87)),
          ),
          if (task.notificationTime != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 12, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 4),
                  Text('${task.notificationTime}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF3B82F6))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── URGENT TASKS ──────────────────────────────
  Widget _buildUpcomingTasksWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      title: 'Urgent Tasks',
      icon: Icons.assignment_late_rounded,
      accentColor: _kWarning,
      onViewAll: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TodoHomeScreen())),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _upcomingTasks.isEmpty
              ? _buildGenericEmptyState(
                  isDark: isDark,
                  icon: Icons.task_outlined,
                  iconColor: _kWarning,
                  title: 'No urgent tasks',
                  subtitle: 'You have no tasks due in the next 3 days',
                )
              : Column(
                  children: _upcomingTasks.take(3).map((task) {
                    final deadlineDate = DateTime(task.deadline!.year,
                        task.deadline!.month, task.deadline!.day);
                    final todayDate = DateTime.now();
                    final today = DateTime(
                        todayDate.year, todayDate.month, todayDate.day);
                    final daysLeft = deadlineDate.difference(today).inDays;
                    final isToday = daysLeft == 0;
                    final accentClr = isToday ? Colors.red : _kWarning;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: accentClr, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? _kTextPrimary : Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '📅 ${DateFormat('MMM d').format(task.deadline!)}',
                                style: const TextStyle(
                                    fontSize: 11, color: _kTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentClr.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isToday
                                ? 'DUE TODAY'
                                : '$daysLeft DAY${daysLeft > 1 ? 'S' : ''}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accentClr),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TodoHomeScreen())),
              icon: const Icon(Icons.task_alt_outlined, size: 16),
              label: const Text('View all tasks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kWarning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── LIBRARY BOOKS ─────────────────────────────
  Widget _buildLibraryBooksWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardCard(
      title: 'Book Returns Due',
      icon: Icons.library_books_rounded,
      accentColor: const Color(0xFF3B82F6),
      onViewAll: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LibraryTrackerScreen())),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _upcomingBooks.isEmpty
              ? _buildGenericEmptyState(
                  isDark: isDark,
                  icon: Icons.menu_book_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'No books due soon',
                  subtitle: 'All your books have plenty of time left',
                )
              : Column(
                  children: _upcomingBooks.take(3).map((book) {
                    final returnDate = DateTime.parse(book.returnDate);
                    final returnDateDay = DateTime(
                        returnDate.year, returnDate.month, returnDate.day);
                    final todayDate = DateTime.now();
                    final today = DateTime(
                        todayDate.year, todayDate.month, todayDate.day);
                    final daysLeft = returnDateDay.difference(today).inDays;
                    final color = daysLeft == 0
                        ? Colors.red
                        : (daysLeft <= 2 ? Colors.orange : Colors.amber);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(book.title,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? _kTextPrimary : Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            daysLeft == 0 ? 'TODAY' : '$daysLeft DAY${daysLeft > 1 ? 'S' : ''}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LibraryTrackerScreen())),
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('View Library'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared friendly empty state for Urgent Tasks and Book Returns
  Widget _buildGenericEmptyState({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? _kTextPrimary : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: _kTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Attendance Hero Card (animated ring + check)
// ──────────────────────────────────────────────
class _AttendanceHeroCard extends StatefulWidget {
  final bool isDark;
  const _AttendanceHeroCard({required this.isDark});

  @override
  State<_AttendanceHeroCard> createState() => _AttendanceHeroCardState();
}

class _AttendanceHeroCardState extends State<_AttendanceHeroCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;
  bool _showCheck = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _progress = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showCheck = true);
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = rw(context, 70);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: rw(context, 16), vertical: rw(context, 8)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDark
              ? [const Color(0xFF0D2818), const Color(0xFF0A1A10)]
              : [const Color(0xFFD1FAE5), const Color(0xFFF0FFF4)],
        ),
        borderRadius: BorderRadius.circular(rw(context, 20)),
        border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(rw(context, 20)),
        child: Row(
          children: [
            // Animated progress ring → check
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _showCheck
                    ? Container(
                        key: const ValueKey('check'),
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kGreen.withValues(alpha: 0.15),
                        ),
                        child: Icon(Icons.check_circle_rounded,
                            size: ri(context, 44), color: _kGreen),
                      )
                    : AnimatedBuilder(
                        key: const ValueKey('ring'),
                        animation: _progress,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _RingPainter(progress: _progress.value),
                            child: SizedBox(width: ringSize, height: ringSize),
                          );
                        },
                      ),
              ),
            ),
            SizedBox(width: rw(context, 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All subjects above 80% 🎉',
                    style: TextStyle(
                      fontSize: rw(context, 15),
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? _kTextPrimary : Colors.black87,
                    ),
                  ),
                  SizedBox(height: rw(context, 6)),
                  Text(
                    "You're on track — keep it going!",
                    style: TextStyle(
                      fontSize: rw(context, 13),
                      color: widget.isDark ? _kTextSecondary : Colors.black54,
                    ),
                  ),
                  SizedBox(height: rw(context, 12)),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HomeScreen())),
                    icon: Icon(Icons.bar_chart_rounded, size: ri(context, 16)),
                    label: Text('View Details', style: TextStyle(fontSize: rw(context, 13))),
                    style: TextButton.styleFrom(
                      foregroundColor: _kGreen,
                      padding: EdgeInsets.symmetric(
                          horizontal: rw(context, 12), vertical: rw(context, 4)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background ring
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _kGreen.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = _kGreen
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ──────────────────────────────────────────────
// Timeline slot item with swipe-to-mark
// ──────────────────────────────────────────────
class _TimelineSlotItem extends StatefulWidget {
  final TimeSlot slot;
  final int index;
  final bool isLast;
  final DateTime now;
  final DateTime todayDate;
  final AttendanceProvider attendanceProvider;
  final TimetableProvider timetableProvider;

  const _TimelineSlotItem({
    required this.slot,
    required this.index,
    required this.isLast,
    required this.now,
    required this.todayDate,
    required this.attendanceProvider,
    required this.timetableProvider,
  });

  @override
  State<_TimelineSlotItem> createState() => _TimelineSlotItemState();
}

class _TimelineSlotItemState extends State<_TimelineSlotItem> {
  double _dragOffset = 0;
  bool _marking = false;

  _SlotStatus _getStatus() {
    final now = widget.now;
    final slotStart = DateTime(now.year, now.month, now.day,
        widget.slot.startTimeHour, widget.slot.startTimeMinute);
    final slotEnd = DateTime(now.year, now.month, now.day,
        widget.slot.endTimeHour, widget.slot.endTimeMinute);

    if (now.isAfter(slotEnd)) return _SlotStatus.completed;
    if (now.isAfter(slotStart) || now.isAtSameMomentAs(slotStart)) {
      return _SlotStatus.ongoing;
    }
    return _SlotStatus.upcoming;
  }

  Future<void> _markAttendance(bool present) async {
    if (_marking) return;
    setState(() {
      _marking = true;
      _dragOffset = 0;
    });
    HapticFeedback.mediumImpact();

    final existingAttendance =
        widget.attendanceProvider.getAttendance(widget.todayDate);

    // Build updated slot sets
    final slotSubjects = Map<String, String>.from(
        existingAttendance?.slotSubjects ?? {});
    final slotAttendance = Map<String, bool>.from(
        existingAttendance?.slotAttendance ?? {});

    slotSubjects[widget.slot.id] = widget.slot.subjectName;
    slotAttendance[widget.slot.id] = present;

    // Compute correct status based on ALL slots for today
    final todaySchedule =
        widget.timetableProvider.getScheduleForDay(widget.todayDate.weekday);
    AttendanceStatus resolvedStatus;
    if (todaySchedule != null && todaySchedule.slots.isNotEmpty) {
      int presentCount = 0;
      for (final s in todaySchedule.slots) {
        if (slotAttendance[s.id] == true) presentCount++;
      }
      if (presentCount == todaySchedule.slots.length) {
        resolvedStatus = AttendanceStatus.present;
      } else if (presentCount == 0) {
        resolvedStatus = AttendanceStatus.absent;
      } else {
        resolvedStatus = AttendanceStatus.partial;
      }
    } else {
      resolvedStatus = present ? AttendanceStatus.present : AttendanceStatus.absent;
    }

    final newAttendance = DailyAttendance(
      date: widget.todayDate,
      status: resolvedStatus,
      slotSubjects: slotSubjects,
      slotAttendance: slotAttendance,
    );

    await widget.attendanceProvider.markAttendance(newAttendance);

    if (mounted) {
      setState(() => _marking = false);

      // Capture a reference to the provider before async gaps
      final provider = widget.attendanceProvider;
      final slotId = widget.slot.id;
      final todayDate = widget.todayDate;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: _SnackBarTimerContent(
            message: '${widget.slot.subjectName}: ${present ? "Present" : "Absent"}',
            duration: const Duration(seconds: 5),
          ),
          backgroundColor: present ? _kGreen : Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () async {
              // Remove this slot from attendance
              final existing = provider.getAttendance(todayDate);
              if (existing != null) {
                final updatedSlotSubjects =
                    Map<String, String>.from(existing.slotSubjects)
                      ..remove(slotId);
                final updatedSlotAttendance =
                    Map<String, bool>.from(existing.slotAttendance)
                      ..remove(slotId);

                final reverted = DailyAttendance(
                  date: todayDate,
                  status: AttendanceStatus.partial,
                  slotSubjects: updatedSlotSubjects,
                  slotAttendance: updatedSlotAttendance,
                );
                await provider.markAttendance(reverted);
              }
            },
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _getStatus();
    final subjectColor = _kSubjectColors[widget.index % _kSubjectColors.length];

    final bool swipeLeft = _dragOffset < -20;
    final bool swipeRight = _dragOffset > 20;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline dot + line
        Column(
          children: [
            Container(
              width: rw(context, 12),
              height: rw(context, 12),
              margin: EdgeInsets.only(top: rw(context, 14)),
              decoration: BoxDecoration(
                color: status == _SlotStatus.ongoing
                    ? _kGreen
                    : status == _SlotStatus.completed
                        ? Colors.grey
                        : subjectColor,
                shape: BoxShape.circle,
                boxShadow: status == _SlotStatus.ongoing
                    ? [BoxShadow(color: _kGreen.withValues(alpha: 0.4), blurRadius: 6)]
                    : [],
              ),
            ),
            if (!widget.isLast)
              Container(
                width: rw(context, 2),
                height: rw(context, 60),
                margin: EdgeInsets.only(top: rw(context, 4)),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        // ── Slot content with swipe
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() => _dragOffset += d.delta.dx);
              _dragOffset = _dragOffset.clamp(-80.0, 80.0);
            },
            onHorizontalDragEnd: (d) {
              if (_dragOffset < -50) {
                _markAttendance(false);
              } else if (_dragOffset > 50) {
                _markAttendance(true);
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Stack(
              children: [
                // Absent reveal (left swipe)
                if (swipeLeft)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: Text('ABSENT',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ),
                // Present reveal (right swipe)
                if (swipeRight)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('PRESENT',
                          style: TextStyle(
                              color: _kGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ),
                // Main card
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(
                          left: BorderSide(color: subjectColor, width: 4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: isDark ? 0.2 : 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: rw(context, 12), vertical: rw(context, 10)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.slot.timeString,
                                  style: TextStyle(
                                    fontSize: rw(context, 13),
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? _kTextPrimary
                                        : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: rw(context, 2)),
                                Text(
                                  widget.slot.subjectName,
                                  style: TextStyle(
                                      fontSize: rw(context, 12), color: _kTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(status),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(_SlotStatus status) {
    final (label, color) = switch (status) {
      _SlotStatus.ongoing => ('Ongoing', _kGreen),
      _SlotStatus.completed => ('Done', Colors.grey),
      _SlotStatus.upcoming => ('Upcoming', const Color(0xFF3B82F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

enum _SlotStatus { upcoming, ongoing, completed }

// ──────────────────────────────────────────────
// Snack-bar content with a circular countdown timer
// ──────────────────────────────────────────────
class _SnackBarTimerContent extends StatefulWidget {
  final String message;
  final Duration duration;
  const _SnackBarTimerContent({
    required this.message,
    required this.duration,
  });

  @override
  State<_SnackBarTimerContent> createState() => _SnackBarTimerContentState();
}

class _SnackBarTimerContentState extends State<_SnackBarTimerContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CircularProgressIndicator(
              value: 1.0 - _ctrl.value,
              strokeWidth: 2.5,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
