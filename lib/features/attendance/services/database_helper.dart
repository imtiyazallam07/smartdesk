import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/timetable.dart';
import '../models/attendance.dart';
import '../models/subject.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 1, 
      onCreate: _createDB
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table for Subjects
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');

    // Table for TimeSlots
    await db.execute('''
      CREATE TABLE slots (
        id TEXT PRIMARY KEY,
        dayOfWeek INTEGER,
        subjectName TEXT, 
        startTimeHour INTEGER,
        startTimeMinute INTEGER,
        endTimeHour INTEGER,
        endTimeMinute INTEGER
      )
    ''');

    // Table for DailyAttendance
    await db.execute('''
      CREATE TABLE daily_attendance (
        date TEXT PRIMARY KEY,
        status INTEGER,
        slotAttendance TEXT,
        slotSubjects TEXT,
        note TEXT
      )
    ''');
  }

  // --- Subject Operations ---
  Future<List<Subject>> getAllSubjects() async {
    final db = await instance.database;
    final result = await db.query('subjects', orderBy: 'name ASC');
    return result.map((json) => Subject.fromMap(json)).toList();
  }

  Future<void> addSubject(Subject subject) async {
    final db = await instance.database;
    await db.insert('subjects', subject.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSubject(String id) async {
    final db = await instance.database;
    
    await db.transaction((txn) async {
       // 1. Get the subject name first to identify related records
       final List<Map<String, dynamic>> subjectMaps = await txn.query(
         'subjects',
         columns: ['name'],
         where: 'id = ?',
         whereArgs: [id],
       );

       if (subjectMaps.isEmpty) return; // Subject not found
       final String subjectName = subjectMaps.first['name'] as String;

       // 2. Delete from subjects table
       await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);

       // 3. Delete from slots table (Timetable)
       await txn.delete('slots', where: 'subjectName = ?', whereArgs: [subjectName]);

       // 4. Update daily_attendance table
       // Fetch all attendance records that might contain this subject.
       final List<Map<String, dynamic>> attendanceMaps = await txn.query(
         'daily_attendance',
         where: 'slotSubjects LIKE ?',
         whereArgs: ['%$subjectName%'], 
       );

       for (var map in attendanceMaps) {
         Map<String, dynamic> mutableMap = Map.from(map);
         
         // Parse JSON fields
         try {
           Map<String, dynamic> slotSubjects = jsonDecode(mutableMap['slotSubjects']);
           Map<String, dynamic> slotAttendance = jsonDecode(mutableMap['slotAttendance']);
           
           bool needsUpdate = false;
           List<String> slotIdsToRemove = [];

           // Find slots with this subject
           slotSubjects.forEach((slotId, subName) {
             if (subName == subjectName) {
               slotIdsToRemove.add(slotId);
               needsUpdate = true;
             }
           });

           if (needsUpdate) {
             // Remove from slotSubjects and slotAttendance
             for (var slotId in slotIdsToRemove) {
               slotSubjects.remove(slotId);
               slotAttendance.remove(slotId);
             }

             mutableMap['slotSubjects'] = jsonEncode(slotSubjects);
             mutableMap['slotAttendance'] = jsonEncode(slotAttendance);

             // Update the record
             await txn.update(
               'daily_attendance',
               mutableMap,
               where: 'date = ?',
               whereArgs: [mutableMap['date']],
             );
           }
         } catch (e) {
           // print("Error parsing attendance record during deletion: $e");
           // Skip if corrupt
         }
       }
    });
  }

  // --- Slots Operations ---
  
  Future<List<TimeSlot>> getSlotsForDay(int dayOfWeek) async {
    final db = await instance.database;
    final result = await db.query(
      'slots',
      where: 'dayOfWeek = ?',
      whereArgs: [dayOfWeek],
      orderBy: 'startTimeHour ASC, startTimeMinute ASC'
    );
    
    return result.map((json) => TimeSlot.fromMap(json)).toList();
  }
  
  Future<void> addSlot(int dayOfWeek, TimeSlot slot) async {
      final db = await instance.database;
      final map = slot.toMap();
      map['dayOfWeek'] = dayOfWeek;
      
      await db.insert('slots', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<void> updateSlot(int dayOfWeek, TimeSlot slot) async {
      final db = await instance.database;
      final map = slot.toMap();
      map['dayOfWeek'] = dayOfWeek;
      
      await db.update(
          'slots', 
          map, 
          where: 'id = ?', 
          whereArgs: [slot.id]
      );
  }
  
  Future<void> deleteSlot(String id) async {
      final db = await instance.database;
      await db.delete(
          'slots',
          where: 'id = ?',
          whereArgs: [id]
      );
  }
  
  Future<Map<int, List<TimeSlot>>> getAllSlots() async {
      final db = await instance.database;
      final result = await db.query('slots');
      
      final Map<int, List<TimeSlot>> schedule = {};
      
      for (var row in result) {
          final slot = TimeSlot.fromMap(row);
          final day = row['dayOfWeek'] as int;
          
          if (!schedule.containsKey(day)) {
              schedule[day] = [];
          }
          schedule[day]!.add(slot);
      }
      
      // Sort
      schedule.forEach((day, slots) {
         slots.sort((a,b) {
            if (a.startTimeHour != b.startTimeHour) return a.startTimeHour.compareTo(b.startTimeHour);
            return a.startTimeMinute.compareTo(b.startTimeMinute);
         });
      });
      
      return schedule;
  }

  // --- Attendance Operations ---

  Future<DailyAttendance?> getAttendance(DateTime date) async {
    final db = await instance.database;
    final dateKey = _getDateKey(date);
    
    final maps = await db.query(
        'daily_attendance',
        where: 'date = ?',
        whereArgs: [dateKey]
    );

    if (maps.isNotEmpty) {
      return DailyAttendance.fromMap(maps.first);
    } 
    return null;
  }
  
  Future<void> markAttendance(DailyAttendance attendance) async {
      final db = await instance.database;
      await db.insert(
          'daily_attendance',
          attendance.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace
      );
  }

  Future<List<DailyAttendance>> getAttendanceForMonth(int year, int month) async {
      final db = await instance.database;
      final prefix = '${year.toString()}-${month.toString().padLeft(2, '0')}';
      
      final result = await db.query(
          'daily_attendance',
          where: 'date LIKE ?',
          whereArgs: ['$prefix%']
      );
      
      return result.map((json) => DailyAttendance.fromMap(json)).toList();
  }

  Future<void> deleteAttendance(DateTime date) async {
      final db = await instance.database;
      final dateKey = _getDateKey(date);
      await db.delete(
          'daily_attendance',
          where: 'date = ?',
          whereArgs: [dateKey]
      );
  }

  String _getDateKey(DateTime date) {
    return '${date.year.toString()}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
  }
}
