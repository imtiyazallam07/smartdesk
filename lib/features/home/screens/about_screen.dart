import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../services/version_service.dart';
import '../../../widgets/update_dialog.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '...';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final versionService = VersionService();
      final updateInfo = await versionService.checkForUpdatesManual();

      if (!mounted) return;

      setState(() {
        _isCheckingUpdate = false;
      });

      if (updateInfo != null) {
        // Show update dialog
        showDialog(
          context: context,
          builder: (context) => UpdateDialog(
            updateInfo: updateInfo,
          ),
        );
      } else {
        // No update available (or rate limited)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are using the latest version'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCheckingUpdate = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to check for updates'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _open(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // print("Error launching: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect system theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About',
          style: TextStyle(color: textColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /// -------------------- App Info --------------------
            const SizedBox(height: 8),
            Image.asset('assets/logo.png', width: 70, height: 70),
            const SizedBox(height: 12),
            Text(
              "SmartDesk",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              _version,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            /// -------------------- Developer Info --------------------
            CircleAvatar(
              radius: 70,
              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              backgroundImage: const NetworkImage(
                "https://avatars.githubusercontent.com/u/95128488?v=4",
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Developed and designed by",
              style: TextStyle(color: subtitleColor, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "Imtiyaz Allam",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _icon(FontAwesomeIcons.instagram,
                    "https://instagram.com/sudo_imtiyaz.sh", iconColor),
                _icon(FontAwesomeIcons.linkedinIn,
                    "https://www.linkedin.com/in/imtiyaz-allam-68b106252/",
                    iconColor),
                _icon(FontAwesomeIcons.github,
                    "https://github.com/imtiyazallam07", iconColor),
                _icon(Icons.mail_outline,
                    "mailto:imtiyazallam07@outlook.com", iconColor),
              ],
            ),

            const SizedBox(height: 32),

            /// -------------------- Support Section --------------------
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                "SUPPORT",
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            _tile(
              "Check for updates",
              textColor,
              _checkForUpdates,
              trailing: _isCheckingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            _tile(
              "Changelog",
              textColor,
                  () => _open(
                  "https://github.com/imtiyazallam07/SmartDesk/releases"),
            ),
            _tile(
              "Provide feedback",
              textColor,
                  () => _open("mailto:imtiyazallam07@outlook.com"),
            ),
            _tile(
              "Open source licences",
              textColor,
                  () => showLicensePage(context: context),
            ),
            _tile(
              "Report bug or outdated data",
              Colors.red,
                  () => _open("mailto:imtiyazallam07@outlook.com"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _icon(IconData icon, String link, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => _open(link),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _tile(String title, Color textColor, VoidCallback onTap, {Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
