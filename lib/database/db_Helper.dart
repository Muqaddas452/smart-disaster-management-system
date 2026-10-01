import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Central database helper for the whole app.
/// All tables (offline reports + offline cache for every feature) live
/// inside a single database file ("offline_reports.db").
class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    // NOTE: filename changed from 'offline_reports.db' to
    // 'offline_reports_v2.db'. This is deliberate and safe — some installs
    // already had the old file on disk at schema version 1 (with only the
    // 'reports' table), and SQLite's onCreate never re-runs for an existing
    // file. Using a brand-new filename forces a truly fresh database with
    // ALL tables, on every device, with NO uninstall needed. Firebase
    // login, Firestore data, and everything else are untouched — only this
    // one local cache file is fresh.
    String path = join(await getDatabasesPath(), 'offline_reports_v2.db');
    return await openDatabase(
      path,
      // Bumped from 1 to 2 because new tables were added after some
      // installs already had version 1 saved on disk. onCreate only runs
      // for a brand-new database file — onUpgrade is what makes sure
      // existing installs (which already have the old 'reports' table)
      // also get the new tables, without losing their existing offline
      // reports.
      //
      // IMPORTANT: if you already ran an earlier build of this app on a
      // device/emulator before this version bump, the database file on
      // that device is stuck at version 1 forever until it's deleted —
      // uninstall the app once (or clear its storage) to get a clean
      // version-2 database. Every install after that upgrades correctly
      // on its own.
      version: 2,
      onCreate: (db, version) async {
        await _createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAllTables(db, ifNotExists: true);
        }
      },
    );
  }

  static Future<void> _createAllTables(Database db, {bool ifNotExists = false}) async {
    final ine = ifNotExists ? 'IF NOT EXISTS ' : '';

    // ── Existing table — manual emergency reports submitted offline,
    // later synced with Firestore. IF NOT EXISTS so upgrading an old
    // install never touches this table or its data.
    await db.execute('''
      CREATE TABLE ${ine}reports (
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
      CREATE TABLE ${ine}cached_citizen_profile (
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

    // ── Rescue leader/member profile cache (both roles fit in this one
    // table — role/isLeader tells them apart)
    await db.execute('''
      CREATE TABLE ${ine}cached_rescue_profile (
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

    // ── Tasks cache (leader's full team task list, or member's assigned
    // tasks — both live in this same table)
    await db.execute('''
      CREATE TABLE ${ine}cached_tasks (
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
      CREATE TABLE ${ine}cached_alerts (
        docId TEXT PRIMARY KEY,
        disasterType TEXT,
        priority TEXT,
        targetArea TEXT,
        message TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    // ── Rescue home screen's "latest active alert" banner (we only
    // keep one row — id is always fixed at 1)
    await db.execute('''
      CREATE TABLE ${ine}cached_rescue_live_alert (
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

    // ── Citizen home screen's "My Reports Status" cache (live status of
    // already-submitted reports — different from the offline `reports`
    // table above, which is for new reports submitted while offline)
    await db.execute('''
      CREATE TABLE ${ine}cached_reports_status (
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
      CREATE TABLE ${ine}cached_shelters (
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
      CREATE TABLE ${ine}cached_safety_tips (
        docId TEXT PRIMARY KEY,
        title TEXT,
        pdfUrl TEXT,
        updatedAt TEXT
      )
    ''');
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
  // HELPER — convert List/Map fields to a JSON string
  // (SQLite cannot store a List/Map directly, only primitive types)
  // ────────────────────────────────────────────────────────────────

  static String encodeList(List data) => jsonEncode(data);

  static List decodeList(String? data) {
    if (data == null || data.isEmpty) return [];
    return jsonDecode(data) as List;
  }
}