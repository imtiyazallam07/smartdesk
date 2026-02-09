// import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:html/parser.dart' as parser;
import 'package:url_launcher/url_launcher.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../calendar/screens/calendar_screen.dart';
import '../../curriculum/screens/curriculum_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'home_dashboard_screen.dart';
import '../../../services/version_service.dart';
import '../../../widgets/update_dialog.dart';

class SmartDesk extends StatefulWidget {
  const SmartDesk({super.key});

  @override
  SmartDeskState createState() => SmartDeskState();
}

class SmartDeskState extends State<SmartDesk> {
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _checkForUpdatesOnStartup();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Check for updates on app startup (automatic check with 24h rate limit)
  Future<void> _checkForUpdatesOnStartup() async {
    if (!mounted) return;

    // Add a small delay to ensure the UI is built
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    try {
      final versionService = VersionService();
      final updateInfo = await versionService.checkForUpdatesAuto();

      if (!mounted) return;

      if (updateInfo != null) {
        // Show update dialog
        showDialog(
          context: context,
          barrierDismissible: updateInfo.updateType != UpdateType.major,
          builder: (context) => UpdateDialog(
            updateInfo: updateInfo,
          ),
        );
      }
    } catch (e) {
      // Silent fail - don't show error to user on startup
    }
  }



  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const HomeDashboardScreen(),
      Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
              SizedBox(height: 20),
              Text(
                "Feature Coming Soon",
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "We are working on something exciting!",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      Calendar(),
      CurriculumPage(
        jsonUrl:
        "https://smart-desk-backend.vercel.app/curriculum.json",
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("SmartDesk", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.computer_outlined, color: Colors.blue[800]),
            onPressed: () async {
              final Uri url = Uri.parse(
                "https://soaportals.com/StudentPortalSOA/#/",
              );
              if (!await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              )) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Could not open portal")),
                  );
                }
              }
            },
            onLongPress: () => Fluttertoast.showToast(
              msg: "SOA Portal",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.black38,
              textColor: Colors.white,
              fontSize: 16.0,
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.blue[800]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            onLongPress: () => Fluttertoast.showToast(
              msg: "Settings and Profile",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.black38,
              textColor: Colors.white,
              fontSize: 16.0,
            ),
          ),

        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.newspaper), label: 'Notices'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book),
            label: 'Curriculum',
          ),
        ],
      ),
    );
  }
}
