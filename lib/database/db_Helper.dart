import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'offline_reports.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT,
            emergencyType TEXT,
            description TEXT,
            severity TEXT,
            location TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  // Offline report insert krne ka function
  static Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    return await db.insert('reports', report);
  }

  // Sari offline reports nikalne ka function (Zaroori jb internet wapas aaye)
  static Future<List<Map<String, dynamic>>> getOfflineReports() async {
    final db = await database;
    return await db.query('reports');
  }

  // Sync hone k baad SQLite se data clear krne ka function
  static Future<void> deleteReport(int id) async {
    final db = await database;
    await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }
}