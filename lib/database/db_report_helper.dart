// lib/database/db_report_helper.dart
// SQLite local database — offline reports store aur sync k liye

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBReportHelper {
  // Singleton pattern — ek hi instance banao
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await DBReportHelper._initDB();
    return _database!;
  }

  // ── DB initialize karna
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'disaster_reports.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table create karna agar pehli baar open ho
        await db.execute('''
          CREATE TABLE reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            emergencyType TEXT NOT NULL,
            description TEXT NOT NULL,
            severity TEXT NOT NULL,
            location TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            timestamp TEXT NOT NULL,
            isSynced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // isSynced = 0 matlab abhi Firestore ko nahi bheja
        // isSynced = 1 matlab sync ho gaya
      },
    );
  }

  // ── Report insert karna (offline save)
  static Future<int> insertReport(Map<String, dynamic> reportData) async {
    final db = await database;
    return await db.insert(
      'reports',
      {
        'name': reportData['name'],
        'phone': reportData['phone'],
        'emergencyType': reportData['emergencyType'],
        'description': reportData['description'],
        'severity': reportData['severity'],
        'location': reportData['location'],
        'latitude': reportData['latitude'],
        'longitude': reportData['longitude'],
        'timestamp': reportData['timestamp'],
        'isSynced': 0, // abhi sync nahi hua
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Woh reports lao jo abhi Firestore ko sync nahi hui (isSynced = 0)
  static Future<List<Map<String, dynamic>>> getUnsyncedReports() async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC', // purani pehle
    );
  }

  // ── Jab Firestore mein save ho jaye to mark as synced
  static Future<void> markAsSynced(int localId) async {
    final db = await database;
    await db.update(
      'reports',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  // ── Synced reports delete karna (optional cleanup)
  static Future<void> deleteSyncedReports() async {
    final db = await database;
    await db.delete(
      'reports',
      where: 'isSynced = ?',
      whereArgs: [1],
    );
  }

  // ── Sari reports (debugging k liye)
  static Future<List<Map<String, dynamic>>> getAllReports() async {
    final db = await database;
    return await db.query('reports', orderBy: 'timestamp DESC');
  }

  // ── Total unsynced count (badge/indicator k liye)
  static Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reports WHERE isSynced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── DB band karna (app close hone par)
  static Future<void> closeDB() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
