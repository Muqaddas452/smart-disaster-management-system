import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Central database helper for the whole app.
/// Saari tables (offline reports + har feature ki cache) yahan
/// ek hi database file ("offline_reports.db") ke andar hain.
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
        // ── Existing table (unchanged) — manual emergency reports jo
        // offline submit hoti hain aur baad mein Firestore ke sath sync hoti hain.
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

        // ── Citizen profile cache
        await db.execute('''
          CREATE TABLE cached_citizen_profile (
            uid TEXT PRIMARY KEY,
            name TEXT,
            email TEXT,
            phone TEXT,
            address TEXT,
            emergencyContactName TEXT,
            emergencyContactPhone TEXT,
            emergencyContactRelation TEXT,
            updatedAt TEXT
          )
        ''');

        // ── Rescue leader/member profile cache (dono role isi table mein
        // fit ho jate hain — role/isLeader se pata chalta hai kaun hai)
        await db.execute('''
          CREATE TABLE cached_rescue_profile (
            uid TEXT PRIMARY KEY,
            name TEXT,
            email TEXT,
            phone TEXT,
            emergencyContact TEXT,
            personalAddress TEXT,
            specialization TEXT,
            bloodGroup TEXT,
            teamName TEXT,
            teamId TEXT,
            officialAddress TEXT,
            role TEXT,
            isLeader INTEGER,
            photoUrl TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');

        // ── Tasks cache (leader ke sare team tasks, ya member ke assigned
        // tasks — dono isi table mein rehte hain)
        await db.execute('''
          CREATE TABLE cached_tasks (
            taskId TEXT PRIMARY KEY,
            type TEXT,
            priority TEXT,
            address TEXT,
            description TEXT,
            status TEXT,
            teamId TEXT,
            assignedMemberIds TEXT,
            assignedMembers TEXT,
            latitude REAL,
            longitude REAL,
            createdAt TEXT,
            statusOverriddenBy TEXT,
            statusOverriddenAt TEXT,
            updatedAt TEXT
          )
        ''');

        // ── Citizen Alerts screen cache (broadcast_alerts collection)
        await db.execute('''
          CREATE TABLE cached_alerts (
            docId TEXT PRIMARY KEY,
            disasterType TEXT,
            priority TEXT,
            targetArea TEXT,
            message TEXT,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');

        // ── Rescue home screen ka "latest active alert" banner (ek hi row
        // rakhte hain — id hamesha 1 fixed rehta hai)
        await db.execute('''
          CREATE TABLE cached_rescue_live_alert (
            id INTEGER PRIMARY KEY,
            title TEXT,
            message TEXT,
            riskLevel TEXT,
            latitude REAL,
            longitude REAL,
            createdAt TEXT,
            updatedAt TEXT
          )
        ''');

        // ── Citizen home screen ka "My Reports Status" cache
        // (submit-shuda reports ka live status — offline `reports` table
        // se alag hai, wo naye offline-submitted reports ke liye hai)
        await db.execute('''
          CREATE TABLE cached_reports_status (
            reportId TEXT PRIMARY KEY,
            description TEXT,
            status TEXT,
            timestamp TEXT,
            reportedBy TEXT,
            updatedAt TEXT
          )
        ''');

        // ── Nearest Help Centers cache (shelters collection)
        await db.execute('''
          CREATE TABLE cached_shelters (
            docId TEXT PRIMARY KEY,
            name TEXT,
            type TEXT,
            location TEXT,
            capacity INTEGER,
            occupied INTEGER,
            lat REAL,
            lng REAL,
            updatedAt TEXT
          )
        ''');

        // ── Safety Tips cache
        await db.execute('''
          CREATE TABLE cached_safety_tips (
            docId TEXT PRIMARY KEY,
            title TEXT,
            pdfUrl TEXT,
            updatedAt TEXT
          )
        ''');
      },
    );
  }

  // ────────────────────────────────────────────────────────────────
  // EXISTING METHODS (unchanged) — offline manual emergency reports
  // ────────────────────────────────────────────────────────────────

  static Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    return await db.insert('reports', report);
  }

  static Future<List<Map<String, dynamic>>> getOfflineReports() async {
    final db = await database;
    return await db.query('reports');
  }

  static Future<void> deleteReport(int id) async {
    final db = await database;
    await db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────────────────────────────────────────────
  // HELPER — List/Map fields ko JSON string mein convert karne ke liye
  // (SQLite mein direct List/Map store nahi ho sakti)
  // ────────────────────────────────────────────────────────────────

  static String encodeList(List data) => jsonEncode(data);

  static List decodeList(String? data) {
    if (data == null || data.isEmpty) return [];
    return jsonDecode(data) as List;
  }
}