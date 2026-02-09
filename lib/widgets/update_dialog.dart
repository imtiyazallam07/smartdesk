import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_service.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  void _openChangelog() async {
    final Uri uri = Uri.parse(updateInfo.changelogUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // Error launching URL
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMajorUpdate = updateInfo.updateType == UpdateType.major;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.system_update,
            color: _getUpdateColor(),
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            updateInfo.updateTypeString,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _getUpdateColor(),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A new version of SmartDesk is available!',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Version',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    updateInfo.currentVersion,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Latest Version',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    updateInfo.latestVersion,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getUpdateColor(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isMajorUpdate) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a major update with significant changes.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Later'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _getUpdateColor(),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            _openChangelog();
            Navigator.of(context).pop();
          },
          child: const Text('Update Now'),
        ),
      ],
    );
  }

  Color _getUpdateColor() {
    switch (updateInfo.updateType) {
      case UpdateType.major:
        return Colors.red;
      case UpdateType.minor:
        return Colors.blue;
      case UpdateType.patch:
        return Colors.green;
    }
  }
}
