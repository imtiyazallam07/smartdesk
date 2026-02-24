import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class SmartDeskState extends State<SmartDesk> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _hasUpdate = false;

  static const String _keyHasPendingUpdate = 'has_pending_update';

  @override
  void initState() {
    super.initState();
    _loadUpdateDotState();
    _checkForUpdatesOnStartup();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUpdateDotState() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_keyHasPendingUpdate) ?? false;
    if (mounted) setState(() => _hasUpdate = pending);
  }

  Future<void> _setUpdateDot(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasPendingUpdate, value);
    if (mounted) setState(() => _hasUpdate = value);
  }

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  /// Check for updates on app startup (automatic check with 24h rate limit)
  Future<void> _checkForUpdatesOnStartup() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    try {
      final versionService = VersionService();
      final updateInfo = await versionService.checkForUpdatesAuto();
      if (!mounted) return;

      if (updateInfo != null) {
        await _setUpdateDot(true);
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          barrierDismissible: updateInfo.updateType != UpdateType.major,
          builder: (ctx) => UpdateDialog(
            updateInfo: updateInfo,
            onUpdatePressed: () {
              _setUpdateDot(false);
            },
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomeDashboardScreen(),
      Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction_rounded,
                  size: 80, color: Colors.grey.withValues(alpha: 0.5)),
              const SizedBox(height: 20),
              const Text(
                "Feature Coming Soon",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "We are working on something exciting!",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      Calendar(),
      CurriculumPage(
        jsonUrl: "https://smart-desk-backend.vercel.app/curriculum.json",
      ),
    ];

    return Scaffold(
      appBar: _buildAppBar(),
      body: pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "SmartDesk",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      centerTitle: true,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.computer_outlined, color: Colors.blue[800]),
          onPressed: () async {
            final Uri url = Uri.parse("https://soaportals.com/StudentPortalSOA/#/");
            final messenger = ScaffoldMessenger.of(context);
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              messenger.showSnackBar(
                const SnackBar(content: Text("Could not open portal")),
              );
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
        Stack(
          clipBehavior: Clip.none,
          children: [
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
            if (_hasUpdate)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF111827) : Colors.white;
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.newspaper_outlined, activeIcon: Icons.newspaper_rounded, label: 'Notices'),
      _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: 'Calendar'),
      _NavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Curriculum'),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 70 + bottomInset,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Row(
          children: [
            ...List.generate(4, (i) => _buildNavItem(items[i], i)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index) {
    final selected = _selectedIndex == index;
    final accent = const Color(0xFF22C55E);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                color: selected ? accent : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: selected ? 11 : 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? accent : Colors.grey,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}
