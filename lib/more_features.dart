import 'package:flutter/material.dart';
import 'package:smartdesk/features/home/screens/about_screen.dart';

import 'features/attendance/screens/home_screen.dart';
import 'features/todo/screens/todo_home_screen.dart';
import 'features/attendance/screens/timetable_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/settings/screens/settings_screen.dart';

// 1. Data Model for a Feature
class Feature {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  Feature({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class AllFeaturesScreen extends StatelessWidget {
  const AllFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Feature> features = [
      Feature(
        title: 'Tasks &\nReminders',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFFE91E63), // Pink/Rose
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
        ),
      ),
      Feature(
        title: 'Attendance\nTracker',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF5CB35D),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        ),
      ),
      Feature(
        title: 'Library Record\nTracker',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFF99014),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LibraryTrackerScreen()),
        ),
      ),
      Feature(
        title: 'Show\nTimetable',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF3399FF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TimetableScreen()),
        ),
      ),
      Feature(
        title: 'Settings &\nProfile',
        icon: Icons.settings_rounded,
        color: const Color(0xFF607D8B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      Feature(
        title: 'App Info\n & Feedback',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'All Features',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: GridView.builder(
          itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (context, index) {
            return FeatureCard(feature: features[index]);
          },
        ),
      ),
    );
  }
}

// 3. Reusable Card Widget
class FeatureCard extends StatelessWidget {
  final Feature feature;

  const FeatureCard({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: feature.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: feature.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular highlight behind icon
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1), // Subtle overlay
                shape: BoxShape.circle,
              ),
              child: Icon(feature.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            // Title text
            Text(
              feature.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.2, // Line spacing
              ),
            ),
          ],
        ),
      ),
    );
  }
}
