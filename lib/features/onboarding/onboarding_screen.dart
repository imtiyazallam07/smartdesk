import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'widgets/onboarding_page.dart';
import '../../services/onboarding_service.dart';
import '../../main.dart' show flutterLocalNotificationsPlugin;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 14;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    
    // Request permissions after Task & Reminder page (page 6)
    if (page == 7 && !_permissionsRequested) {
      _requestNotificationPermissions();
    }
  }

  bool _permissionsRequested = false;

  Future<void> _requestNotificationPermissions() async {
    _permissionsRequested = true;
    
    // Import needed at top of file
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Request notification permission
      await androidImplementation.requestNotificationsPermission();
      
      // Request exact alarm permission
      final hasExactAlarmPermission = await androidImplementation.canScheduleExactNotifications();
      if (hasExactAlarmPermission == false) {
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() async {
    await OnboardingService().completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _completeOnboarding() async {
    await OnboardingService().completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            if (_currentPage < _totalPages - 1)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              const SizedBox(height: 48),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: _buildPages(),
              ),
            ),

            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.blue
                          : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),

                  // Next/Get Started button
                  ElevatedButton(
                    onPressed: _currentPage < _totalPages - 1
                        ? _nextPage
                        : _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _currentPage < _totalPages - 1 ? 'Next' : 'Get Started',
                      style: const TextStyle(fontSize: 16),
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

  List<Widget> _buildPages() {
    return [
      // Page 1: Welcome to SmartDesk
      OnboardingPage(
        icon: Icons.school_rounded,
        title: 'Welcome to SmartDesk',
        description: 'Your all-in-one academic companion for managing classes, assignments, and academic life at SOA University.',
        iconColor: Colors.blue,
      ),

      // Page 2: Home Screen
      const OnboardingPage(
        icon: Icons.home_rounded,
        title: 'Home Screen',
        description: 'Navigate using the bottom bar. Top-right corner has two buttons: Computer icon (SOA Portal) and Settings icon (Gear). Four tabs: Home, Notices, Calendar, Curriculum.',
        iconColor: Colors.orange,
      ),

      // Page 3: Settings
      const OnboardingPage(
        icon: Icons.settings_rounded,
        title: 'Settings',
        description: 'Access via the Settings icon (gear) in top-right of Home screen. Configure your joining year and branch. Find "App Info & Feedback" here too.',
        iconColor: Colors.purple,
      ),

      // Page 4: Academic Calendar
      const OnboardingPage(
        icon: Icons.calendar_month_rounded,
        title: 'Academic Calendar',
        description: 'Stay updated with holidays and important dates. Sync events with your device calendar and never miss an important day.',
        iconColor: Colors.green,
      ),

      // Page 5: Curriculum
      const OnboardingPage(
        icon: Icons.menu_book_rounded,
        title: 'Curriculum',
        description: 'Browse your subject curriculum and access course materials. Stay on track with your syllabus throughout the semester.',
        iconColor: Colors.teal,
      ),

      // Page 6: Library Tracker
      const OnboardingPage(
        icon: Icons.book_rounded,
        title: 'Library Record Tracker',
        description: 'Track borrowed books, set return reminders, and manage your library records efficiently. Never pay late fees again!',
        iconColor: Colors.brown,
      ),

      // Page 7: Tasks & Reminders
      const OnboardingPage(
        icon: Icons.task_alt_rounded,
        title: 'Tasks & Reminders',
        description: 'Create to-do lists, set reminders for assignments, and keep track of all your academic tasks in one place.\n\nPermission Required: Allow notifications and alarms to receive reminders on time.',
        iconColor: Colors.pink,
      ),

      // Page 8: Timetable Overview
      const OnboardingPage(
        icon: Icons.schedule_rounded,
        title: 'Timetable',
        description: 'Access from Home page "More Features" card. Create your personalized class schedule with a visual weekly view. Quickly see today\'s classes.',
        iconColor: Colors.indigo,
      ),

      // Page 8a: Adding Subjects
      const OnboardingPage(
        icon: Icons.add_circle_outline_rounded,
        title: 'Managing Subjects',
        description: 'Within Timetable screen, tap the book icon (top-right) to manage subjects. Add, edit, or remove subjects from your course list.',
        iconColor: Colors.cyan,
      ),

      // Page 8b: Setting Timetable
      const OnboardingPage(
        icon: Icons.edit_calendar_rounded,
        title: 'Setting Timetable',
        description: 'Tap schedule icon (top-right) in Timetable screen. Interactive time slot selection with visual timeline (8 AM - 6 PM). 1-3 hour durations.',
        iconColor: Colors.deepOrange,
      ),

      // Page 8c: QR Import/Export
      const OnboardingPage(
        icon: Icons.qr_code_rounded,
        title: 'QR Import/Export',
        description: 'Share your timetable via QR code or import from others. Perfect for quick setup on new devices or sharing with friends.',
        iconColor: Colors.deepPurple,
      ),

      // Page 9: Attendance Tracker
      const OnboardingPage(
        icon: Icons.how_to_reg_rounded,
        title: 'Attendance Tracker',
        description: 'Access from Home page "More Features" card. View attendance statistics with subject-wise breakdown. Monitor your attendance percentage.',
        iconColor: Colors.red,
      ),

      // Page 9a: Attendance Setup
      const OnboardingPage(
        icon: Icons.settings_applications_rounded,
        title: 'Attendance Setup',
        description: 'Use book icon and schedule icon (top-right) in Attendance screen to set up subjects and timetable. Links automatically with your timetable.',
        iconColor: Colors.lime,
      ),

      // Page 9b: Marking Attendance
      const OnboardingPage(
        icon: Icons.check_circle_outline_rounded,
        title: 'Marking Attendance',
        description: 'Tap any date in the calendar to mark. Choose Present, Absent, Partial, or Holiday. Quick buttons available for faster marking.',
        iconColor: Colors.amber,
      ),
    ];
  }
}
