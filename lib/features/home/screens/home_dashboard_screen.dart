import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../attendance/providers/attendance_provider.dart';
import '../../attendance/providers/timetable_provider.dart';
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

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<RecurringTask> _todayRecurringTasks = [];
  List<OneTimeTask> _upcomingTasks = [];
  List<Book> _upcomingBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to access context after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
    _loadData();
  }

  Future<void> _initializeProviders() async {
    // Initialize providers to ensure data is loaded
    final timetableProvider = Provider.of<TimetableProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    
    await timetableProvider.init();
    await attendanceProvider.loadMonth(DateTime.now().year, DateTime.now().month);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load recurring tasks for today
    final allRecurringTasks = await TodoDatabaseHelper.instance.getRecurringTasks();
    final todayTasks = _filterTodayRecurringTasks(allRecurringTasks);

    // Load upcoming one-time tasks (deadline < 3 days)
    final allOneTimeTasks = await TodoDatabaseHelper.instance.getOneTimeTasks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingTasks = allOneTimeTasks.where((task) {
      if (task.isCompleted) return false;
      if (task.deadline == null) return false;
      final deadlineDate = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
      final daysUntilDeadline = deadlineDate.difference(today).inDays;
      return daysUntilDeadline >= 0 && daysUntilDeadline < 3;
    }).toList();

    // Load library books with return date <= 5 days
    final allBooks = await LibraryDatabaseHelper.instance.readAllBooks();
    final upcomingBooks = allBooks.where((book) {
      if (book.isReturned == 1) return false;
      try {
        final returnDate = DateTime.parse(book.returnDate);
        final returnDateDay = DateTime(returnDate.year, returnDate.month, returnDate.day);
        final daysUntilReturn = returnDateDay.difference(today).inDays;
        return daysUntilReturn >= 0 && daysUntilReturn <= 5;
      } catch (e) {
        return false;
      }
    }).toList();

    if (mounted) {
      setState(() {
        _todayRecurringTasks = todayTasks;
        _upcomingTasks = upcomingTasks;
        _upcomingBooks = upcomingBooks;
        _isLoading = false;
      });
    }
  }

  List<RecurringTask> _filterTodayRecurringTasks(List<RecurringTask> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayOfWeek = now.weekday; // 1=Monday, 7=Sunday

    return tasks.where((task) {
      if (!task.isActive) return false;

      // Check date range (normalize dates for comparison)
      if (task.fromDate != null) {
        final fromDate = DateTime(task.fromDate!.year, task.fromDate!.month, task.fromDate!.day);
        if (today.isBefore(fromDate)) return false;
      }
      if (task.toDate != null) {
        final toDate = DateTime(task.toDate!.year, task.toDate!.month, task.toDate!.day);
        if (today.isAfter(toDate)) return false;
      }

      // Check repeat type
      if (task.repeatType == 0) {
        // Every working day (Monday to Friday)
        return dayOfWeek >= 1 && dayOfWeek <= 5;
      } else if (task.repeatType == 1) {
        // Specific days
        if (task.repeatDays == null || task.repeatDays!.isEmpty) return false;
        try {
          final days = task.repeatDays!.split(',').map((s) => int.parse(s.trim())).toList();
          return days.contains(dayOfWeek);
        } catch (e) {
          return false;
        }
      } else if (task.repeatType == 2) {
        // Interval
        if (task.intervalDays == null || task.fromDate == null) return false;
        final fromDate = DateTime(task.fromDate!.year, task.fromDate!.month, task.fromDate!.day);
        final daysSinceStart = today.difference(fromDate).inDays;
        return daysSinceStart >= 0 && daysSinceStart % task.intervalDays! == 0;
      }

      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(context),
                  const SizedBox(height: 20),
                  _buildAttendanceWidget(),
                  _buildRecurringTasksWidget(),
                  _buildUpcomingTasksWidget(),
                  _buildTodayTimetableWidget(),
                  _buildLibraryBooksWidget(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    // User requested 4 specific features: Task & Reminder, Attendance Tracker, Library Record Tracker, Show Timetable
    // Let's use those instead of the placeholder one I wrote above initially to match the prompt exactly.
    // "show all the 4 features in the similar manner (Task & Reminder, Attendance Tracker, Library Record Tracker, Show Timetable)"
    
    final List<Feature> quickFeatures = [
      Feature(
        title: 'Tasks & Reminder',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFFE91E63),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
        ),
      ),
      Feature(
        title: 'Attendance Tracker',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF5CB35D),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        ),
      ),
      Feature(
        title: 'Library Record Tracker',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFF99014),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LibraryTrackerScreen()),
        ),
      ),
      Feature(
        title: 'Show Timetable',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF3399FF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TimetableScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: quickFeatures.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
        ),
        itemBuilder: (context, index) {
          final feature = quickFeatures[index];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: feature.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100, // Card background
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: feature.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature.icon,
                        color: feature.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Text(
                        feature.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildAttendanceWidget() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
        final now = DateTime.now();
        final stats = attendanceProvider.getMonthlySubjectStats(now.year, now.month);
        
        // Filter subjects with attendance < 80%
        final lowAttendanceSubjects = stats.entries
            .where((entry) => entry.value['percentage'] < 80.0)
            .toList();

        // Sort by percentage (lowest first - most critical)
        lowAttendanceSubjects.sort((a, b) => 
            (a.value['percentage'] as double).compareTo(b.value['percentage'] as double));

        return DashboardCard(
          title: 'Low Attendance Alert',
          icon: Icons.warning_amber_rounded,
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
          content: lowAttendanceSubjects.isEmpty
              ? Center(
                child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'All subjects above 80%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep up the great work! 🎉',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
              )
              : Column(
                  children: lowAttendanceSubjects.map((entry) {
                    final subject = entry.key;
                    final percentage = entry.value['percentage'] as double;
                    final present = entry.value['present'] as int;
                    final total = entry.value['total'] as int;
                    final absent = total - present;
                    final color = _getColorForPercentage(percentage);
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Donut chart with percentage in center
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sections: [
                                        PieChartSectionData(
                                          value: present.toDouble(),
                                          color: color,
                                          radius: 12,
                                          showTitle: false,
                                        ),
                                        PieChartSectionData(
                                          value: absent.toDouble(),
                                          color: isDark 
                                              ? Colors.grey.shade700 
                                              : Colors.grey.shade200,
                                          radius: 12,
                                          showTitle: false,
                                        ),
                                      ],
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 22,
                                      startDegreeOffset: -90,
                                    ),
                                  ),
                                  // Percentage in center
                                  Text(
                                    '${percentage.toInt()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Subject details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  // Progress bar
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: isDark 
                                          ? Colors.grey.shade700 
                                          : Colors.grey.shade200,
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: percentage / 100,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(3),
                                          gradient: LinearGradient(
                                            colors: [color, color.withValues(alpha: 0.7)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 14,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$present',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.cancel_outlined,
                                        size: 14,
                                        color: Colors.red.shade400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$absent',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'of $total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status indicator
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                percentage < 60 
                                    ? Icons.priority_high 
                                    : Icons.trending_down,
                                size: 20,
                                color: color,
                              ),
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

  Widget _buildRecurringTasksWidget() {
    return DashboardCard(
      title: 'Today\'s Reminders',
      icon: Icons.event_repeat,
      onViewAll: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
        );
      },
      content: _todayRecurringTasks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No recurring tasks for today',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: _todayRecurringTasks.take(3).map((task) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
                  title: Text(task.title),
                  subtitle: task.notificationTime != null
                      ? Text('⏰ ${task.notificationTime}')
                      : null,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildUpcomingTasksWidget() {
    return DashboardCard(
      title: 'Urgent Tasks',
      icon: Icons.assignment_late,
      onViewAll: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
        );
      },
      content: _upcomingTasks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No urgent tasks in upcoming 3 days',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: _upcomingTasks.take(3).map((task) {
                final deadlineDate = DateTime(task.deadline!.year, task.deadline!.month, task.deadline!.day);
                final todayDate = DateTime.now();
                final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
                final daysLeft = deadlineDate.difference(today).inDays;
                final color = daysLeft == 0 ? Colors.red : Colors.orange;
                
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.warning, color: color),
                  title: Text(task.title),
                  subtitle: Text(
                    'Due: ${DateFormat('MMM d').format(task.deadline!)} (${daysLeft == 0 ? 'Today' : '$daysLeft days'})',
                    style: TextStyle(color: color),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTodayTimetableWidget() {
    return Consumer<TimetableProvider>(
      builder: (context, timetableProvider, child) {
        final now = DateTime.now();
        final dayOfWeek = now.weekday;
        final schedule = timetableProvider.getScheduleForDay(dayOfWeek);

        return DashboardCard(
          title: 'Today\'s Classes',
          icon: Icons.schedule,
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimetableScreen()),
            );
          },
          content: schedule == null || schedule.slots.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No classes scheduled for today',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: schedule.slots.take(4).map((slot) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.class_, color: Colors.purple),
                      title: Text(slot.subjectName),
                      subtitle: Text(slot.timeString),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Widget _buildLibraryBooksWidget() {
    return DashboardCard(
      title: 'Book Returns Due',
      icon: Icons.library_books,
      onViewAll: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LibraryTrackerScreen()),
        );
      },
      content: _upcomingBooks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No books due soon',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: _upcomingBooks.take(3).map((book) {
                final returnDate = DateTime.parse(book.returnDate);
                final returnDateDay = DateTime(returnDate.year, returnDate.month, returnDate.day);
                final todayDate = DateTime.now();
                final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
                final daysLeft = returnDateDay.difference(today).inDays;
                final color = daysLeft == 0 ? Colors.red : (daysLeft <= 2 ? Colors.orange : Colors.amber);
                
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.menu_book, color: color),
                  title: Text(book.title),
                  subtitle: Text(
                    'Return: ${DateFormat('MMM d').format(returnDate)} (${daysLeft == 0 ? 'Today' : '$daysLeft days'})',
                    style: TextStyle(color: color),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
