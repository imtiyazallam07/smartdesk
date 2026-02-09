
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/imtiyaz-allam/SmartDesk-backend/refs/heads/main/latest_version.txt';
  static const String _changelogUrl =
      'https://github.com/imtiyazallam07/SmartDesk/releases';

  // SharedPreferences keys
  static const String _keyLastAutoCheck = 'last_auto_version_check';
  static const String _keyLastManualCheck = 'last_manual_version_check';
  static const String _keyCachedLatestVersion = 'cached_latest_version';
  static const String _keyCachedChangelogUrl = 'cached_changelog_url';

  // Rate limiting durations
  static const Duration _autoCheckInterval = Duration(hours: 24);
  static const Duration _manualCheckInterval = Duration(hours: 1);

  /// Get current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Check for updates (automatic check)
  /// Returns UpdateInfo if update available, null otherwise
  /// Respects 24-hour rate limit
  Future<UpdateInfo?> checkForUpdatesAuto() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_keyLastAutoCheck);

    // Check rate limit
    if (lastCheck != null) {
      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      final now = DateTime.now();
      if (now.difference(lastCheckTime) < _autoCheckInterval) {
        return null; // Too soon
      }
    }

    // Update last check time
    await prefs.setInt(_keyLastAutoCheck, DateTime.now().millisecondsSinceEpoch);

    return await _performVersionCheck();
  }

  /// Check for updates (manual check)
  /// Returns UpdateInfo if update available, null otherwise
  /// Respects 1-hour rate limit by returning cached result if available
  Future<UpdateInfo?> checkForUpdatesManual() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_keyLastManualCheck);

    // Check rate limit
    if (lastCheck != null) {
      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      final now = DateTime.now();
      if (now.difference(lastCheckTime) < _manualCheckInterval) {
        // Return cached update info if available and valid
        final cachedVersion = prefs.getString(_keyCachedLatestVersion);
        final cachedChangelog = prefs.getString(_keyCachedChangelogUrl);

        if (cachedVersion != null && cachedChangelog != null) {
          final currentVersion = await getCurrentVersion();
          final comparison = _compareVersions(currentVersion, cachedVersion);

          if (comparison < 0) {
             final updateType = _determineUpdateType(currentVersion, cachedVersion);
             return UpdateInfo(
              currentVersion: currentVersion,
              latestVersion: cachedVersion,
              updateType: updateType,
              changelogUrl: cachedChangelog,
            );
          }
        }

        return null; // Too soon, and no cached update available
      }
    }

    // Update last check time
    await prefs.setInt(_keyLastManualCheck, DateTime.now().millisecondsSinceEpoch);

    return await _performVersionCheck();
  }

  /// Perform the actual version check
  Future<UpdateInfo?> _performVersionCheck() async {
    try {
      final response = await http.get(Uri.parse(_versionUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final remoteVersion = response.body.trim();
      final currentVersion = await getCurrentVersion();
      final prefs = await SharedPreferences.getInstance();

      // Compare versions
      final comparison = _compareVersions(currentVersion, remoteVersion);
      if (comparison < 0) {
        // Update available
        final updateType = _determineUpdateType(currentVersion, remoteVersion);
        
        // Cache the update info
        await prefs.setString(_keyCachedLatestVersion, remoteVersion);
        await prefs.setString(_keyCachedChangelogUrl, _changelogUrl);

        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: remoteVersion,
          updateType: updateType,
          changelogUrl: _changelogUrl,
        );
      } else {
        // No update available, clear cache to avoid stale prompts
        await prefs.remove(_keyCachedLatestVersion);
        await prefs.remove(_keyCachedChangelogUrl);
      }

      return null; // No update available
    } catch (e) {
      // Network error or parsing error
      return null;
    }
  }

  /// Compare two semantic versions
  /// Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Ensure both have 3 parts
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }

  /// Determine update type based on semantic versioning
  UpdateType _determineUpdateType(String current, String latest) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Ensure both have 3 parts
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }

    if (latestParts[0] > currentParts[0]) {
      return UpdateType.major;
    } else if (latestParts[1] > currentParts[1]) {
      return UpdateType.minor;
    } else {
      return UpdateType.patch;
    }
  }
}

enum UpdateType {
  major,
  minor,
  patch,
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final UpdateType updateType;
  final String changelogUrl;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateType,
    required this.changelogUrl,
  });

  String get updateTypeString {
    switch (updateType) {
      case UpdateType.major:
        return 'Major Update';
      case UpdateType.minor:
        return 'Minor Update';
      case UpdateType.patch:
        return 'Bug Fix';
    }
  }
}
