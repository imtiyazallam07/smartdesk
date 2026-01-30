// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:html/parser.dart' as parser;
import 'package:smartdesk/more_features.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../calendar/screens/calendar_screen.dart';
import '../../curriculum/screens/curriculum_screen.dart';
import 'home_dashboard_screen.dart';

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
    _checkForUpdates();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;

    try {
      String currentVersion = "1.9.0";
      final response = await http.get(
        Uri.parse(
          "https://raw.githubusercontent.com/imtiyaz-allam/SmartDesk-backend/refs/heads/main/latest_version.txt",
        ),
      );

      if (response.statusCode == 200) {
        String serverVersion = response.body.trim();
        if (currentVersion != serverVersion) {
          _showVersionMismatchDialog(serverVersion);
        }
      }
    } catch (e) {
      // print("Update check failed: $e");
    }
  }

  void _showVersionMismatchDialog(String serverVersion) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text("Newer Version Available!"),
        content: Text(
          "A newer version ($serverVersion) is available. Would you like to check out the update?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Stay on this version"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(
                "https://github.com/imtiyazallam07/SmartDesk/releases/download/v$serverVersion/SmartDesk-v$serverVersion.apk",
              );
            },
            child: Text("Check Out"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String fullLink) async {
    final Uri url = Uri.parse(fullLink);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
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
            icon: Icon(Icons.more_horiz, color: Colors.blue[800]),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllFeaturesScreen()),
            ),
            onLongPress: () => Fluttertoast.showToast(
              msg: "All features and Information",
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
