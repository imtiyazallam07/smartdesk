import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../models/book.dart';

class LibraryDatabaseHelper {
  static final LibraryDatabaseHelper instance = LibraryDatabaseHelper._init();
  static Database? _database;

  LibraryDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('books_tracker_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, filePath);
    return await openDatabase(fullPath, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE books ( 
  id $idType, 
  title $textType,
  returnDate $textType,
  issueDate $textNullable,
  accessionNumber $textNullable,
  author $textNullable,
  isReturned $boolType DEFAULT 0
  )
''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE books ADD COLUMN isReturned INTEGER DEFAULT 0');
    }
  }

  Future<int> create(Book book) async {
    final db = await instance.database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> readAllBooks() async {
    final db = await instance.database;
    final orderBy = 'returnDate ASC';
    final result = await db.query('books', orderBy: orderBy);
    return result.map((json) => Book.fromMap(json)).toList();
  }

  Future<int> update(Book book) async {
    final db = await instance.database;
    return await db.update('books', book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
