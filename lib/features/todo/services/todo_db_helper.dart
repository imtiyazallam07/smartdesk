import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo_model.dart';

class TodoDatabaseHelper {
  static final TodoDatabaseHelper instance = TodoDatabaseHelper._init();
  static Database? _database;

  TodoDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('todo_list.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
      await db.execute('ALTER TABLE recurring_tasks ADD COLUMN calendarEventId TEXT');
      await db.execute('ALTER TABLE one_time_tasks ADD COLUMN calendarEventId TEXT');
    }


  Future<void> _createDB(Database db, int version) async {
    // Table for Recurring Tasks
    await db.execute('''
      CREATE TABLE recurring_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        repeatType INTEGER NOT NULL,
        repeatDays TEXT,
        intervalDays INTEGER,
        fromDate TEXT,
        toDate TEXT,
        isPriority INTEGER,
        isNotificationEnabled INTEGER,
        notificationTime TEXT,
        isActive INTEGER,
        calendarEventId TEXT
      )
    ''');

    // Table for One-Time Tasks
    await db.execute('''
      CREATE TABLE one_time_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        deadline TEXT,
        isNotificationEnabled INTEGER,
        remindInDays INTEGER,
        notificationTime TEXT,
        isCompleted INTEGER,
        calendarEventId TEXT
      )
    ''');
  }

  // --- Recurring Task Operations ---
  Future<int> createRecurringTask(RecurringTask task) async {
    final db = await instance.database;
    return await db.insert('recurring_tasks', task.toMap());
  }

  Future<List<RecurringTask>> getRecurringTasks() async {
    final db = await instance.database;
    final result = await db.query('recurring_tasks');
    return result.map((json) => RecurringTask.fromMap(json)).toList();
  }

  Future<int> updateRecurringTask(RecurringTask task) async {
    final db = await instance.database;
    return await db.update(
      'recurring_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteRecurringTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'recurring_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- One-Time Task Operations ---
  Future<int> createOneTimeTask(OneTimeTask task) async {
    final db = await instance.database;
    return await db.insert('one_time_tasks', task.toMap());
  }

  Future<List<OneTimeTask>> getOneTimeTasks() async {
    final db = await instance.database;
    // Order by completed status (incomplete first), then deadline
    final result = await db.rawQuery('SELECT * FROM one_time_tasks ORDER BY isCompleted ASC, deadline ASC');
    return result.map((json) => OneTimeTask.fromMap(json)).toList();
  }

  Future<int> updateOneTimeTask(OneTimeTask task) async {
    final db = await instance.database;
    return await db.update(
      'one_time_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteOneTimeTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'one_time_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
