import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../todo/services/todo_db_helper.dart';
import '../../attendance/services/database_helper.dart';
import '../../library/services/library_database_helper.dart';

class BackupService {
  static final _key = encrypt.Key.fromUtf8('SmartDesk_V3_BackupKey_32BitsA!!');
  static final _iv = encrypt.IV.fromUtf8('SmartDesk_IV1234');
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static Future<bool> _requestStoragePermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      if (await Permission.storage.isGranted) {
        return true;
      }
      
      // Request
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      return statuses[Permission.storage] == PermissionStatus.granted ||
             statuses[Permission.manageExternalStorage] == PermissionStatus.granted;
    }
    return true;
  }

  static Future<bool> exportData(BuildContext context) async {
    try {
      // 1. Close connections so files are flushed
      await TodoDatabaseHelper.instance.closeDatabase();
      await DatabaseHelper.instance.closeDatabase();
      await LibraryDatabaseHelper.instance.closeDatabase();



      // 3. Read Database files directly
      final dbPath = await getDatabasesPath();
      final todoFile = File(path.join(dbPath, 'todo_list.db'));
      final attendanceFile = File(path.join(dbPath, 'attendance_tracker.db'));
      final libraryFile = File(path.join(dbPath, 'books_tracker_v2.db'));

      String todoBase64 = todoFile.existsSync()
          ? base64Encode(await todoFile.readAsBytes())
          : "";
      String attendanceBase64 = attendanceFile.existsSync()
          ? base64Encode(await attendanceFile.readAsBytes())
          : "";
      String libraryBase64 = libraryFile.existsSync()
          ? base64Encode(await libraryFile.readAsBytes())
          : "";

      // 4. Read User Settings
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> prefsMap = {
        'joining_year': prefs.getInt('joining_year'),
        'student_branch': prefs.getString('student_branch'),
        'theme_mode': prefs.getString('theme_mode'),
        'home_widget_timetable': prefs.getBool('home_widget_timetable'),
        'home_widget_tasks': prefs.getBool('home_widget_tasks'),
        'home_widget_books': prefs.getBool('home_widget_books'),
      };

      // 5. Create Payload
      final Map<String, dynamic> payload = {
        'todo_list.db': todoBase64,
        'attendance_tracker.db': attendanceBase64,
        'books_tracker_v2.db': libraryBase64,
        'preferences': prefsMap,
      };

      final jsonPayload = jsonEncode(payload);

      // 6. Encrypt
      final encrypted = _encrypter.encrypt(jsonPayload, iv: _iv);

      // 7. Write File
      final bytes = Uint8List.fromList(utf8.encode(encrypted.base64));
      
      // Request permissions before opening picker
      await _requestStoragePermissions();

      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      // Use saveFile which presents a proper save dialog (ACTION_CREATE_DOCUMENT)
      // instead of getDirectoryPath which uses SAF tree picker and restricts many folders
      String? savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save SmartDesk Backup',
        fileName: 'SmartDesk_Backup_$timestamp.sdb',
        type: FileType.any,
        bytes: bytes,
      );

      if (savedPath == null) {
        return false;
      }

      // On some platforms, saveFile with bytes writes directly.
      // On others, it just returns the path and we need to write.
      final finalFile = File(savedPath);
      if (!await finalFile.exists() || await finalFile.length() == 0) {
        await finalFile.writeAsBytes(bytes);
      }

      return true;
    } catch (e) {
      debugPrint("Export failed: $e");
      return false;
    }
  }

  static Future<bool> importData() async {
    try {
      // Request permissions before opening picker
      await _requestStoragePermissions();

      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        dialogTitle: 'Select your SmartDesk Backup file (.sdb)',
      );

      if (result != null && result.files.single.path != null) {
        File backupFile = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // Allow .sdb files and previously incorrectly named files like .sdb (1)
        if (!fileName.endsWith('.sdb') && !RegExp(r'\.sdb \(\d+\)$').hasMatch(fileName)) {
          throw Exception("Invalid backup file extension.");
        }

        String encryptedBase64Str = await backupFile.readAsString();
        encryptedBase64Str = encryptedBase64Str.trim();

        // Decrypt
        final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64Str);
        final decryptedJsonStr = _encrypter.decrypt(encrypted, iv: _iv);

        final payload = jsonDecode(decryptedJsonStr) as Map<String, dynamic>;

        // Overwrite the files
        await TodoDatabaseHelper.instance.closeDatabase();
        await DatabaseHelper.instance.closeDatabase();
        await LibraryDatabaseHelper.instance.closeDatabase();

        final dbPath = await getDatabasesPath();

        if (payload['todo_list.db'] != null &&
            payload['todo_list.db'].toString().isNotEmpty) {
          File(
            path.join(dbPath, 'todo_list.db'),
          ).writeAsBytesSync(base64Decode(payload['todo_list.db']));
        }
        if (payload['attendance_tracker.db'] != null &&
            payload['attendance_tracker.db'].toString().isNotEmpty) {
          File(
            path.join(dbPath, 'attendance_tracker.db'),
          ).writeAsBytesSync(base64Decode(payload['attendance_tracker.db']));
        }
        if (payload['books_tracker_v2.db'] != null &&
            payload['books_tracker_v2.db'].toString().isNotEmpty) {
          File(
            path.join(dbPath, 'books_tracker_v2.db'),
          ).writeAsBytesSync(base64Decode(payload['books_tracker_v2.db']));
        }

        // Restore User Settings
        if (payload['preferences'] != null) {
          final Map<String, dynamic> prefsMap =
              payload['preferences'] as Map<String, dynamic>;
          final prefs = await SharedPreferences.getInstance();
          if (prefsMap['joining_year'] != null)
            await prefs.setInt('joining_year', prefsMap['joining_year']);
          if (prefsMap['student_branch'] != null)
            await prefs.setString('student_branch', prefsMap['student_branch']);
          if (prefsMap['theme_mode'] != null)
            await prefs.setString('theme_mode', prefsMap['theme_mode']);
          if (prefsMap['home_widget_timetable'] != null)
            await prefs.setBool(
              'home_widget_timetable',
              prefsMap['home_widget_timetable'],
            );
          if (prefsMap['home_widget_tasks'] != null)
            await prefs.setBool(
              'home_widget_tasks',
              prefsMap['home_widget_tasks'],
            );
          if (prefsMap['home_widget_books'] != null)
            await prefs.setBool(
              'home_widget_books',
              prefsMap['home_widget_books'],
            );
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Import failed: $e");
      return false;
    }
  }
}
