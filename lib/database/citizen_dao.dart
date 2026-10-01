import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// Data Access Object for everything on the Citizen side:
/// profile, alerts, reports status, shelters, and safety tips.
/// This file does NOT create tables — DBHelper already did that.
/// It only knows how to insert/read/delete rows in those tables.
class CitizenDao {
  // ────────────────────────────────────────────────────────────────
  // CITIZEN PROFILE
  // ────────────────────────────────────────────────────────────────

  /// Save (or overwrite) the citizen's profile in the local cache.
  /// Call this every time fresh data arrives from Firestore.
  static Future<void> cacheProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String address,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String emergencyContactRelation,
  }) async {
    final db = await DBHelper.database;
    await db.insert(
      'cached_citizen_profile',
      {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'emergencyContactRelation': emergencyContactRelation,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      // If a row with this uid already exists, replace it instead of
      // throwing a "duplicate primary key" error.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Read the cached profile for a given uid. Returns null if nothing
  /// has been cached yet (e.g. very first app install, no internet ever).
  static Future<Map<String, dynamic>?> getCachedProfile(String uid) async {
    final db = await DBHelper.database;
    final rows = await db.query(
      'cached_citizen_profile',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  // ────────────────────────────────────────────────────────────────
  // ALERTS (Alerts screen)
  // ────────────────────────────────────────────────────────────────

  /// Cache a whole batch of alerts at once. We clear the old cache first
  /// so removed/expired alerts don't linger forever offline.
  static Future<void> cacheAlerts(List<Map<String, dynamic>> alerts) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    batch.delete('cached_alerts');
    for (final alert in alerts) {
      batch.insert(
        'cached_alerts',
        {
          'docId': alert['docId'],
          'disasterType': alert['disasterType'],
          'priority': alert['priority'],
          'targetArea': alert['targetArea'],
          'message': alert['message'],
          'createdAt': alert['createdAt'],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedAlerts() async {
    final db = await DBHelper.database;
    return db.query('cached_alerts', orderBy: 'createdAt DESC');
  }

  // ────────────────────────────────────────────────────────────────
  // "MY REPORTS STATUS" (Home screen)
  // ────────────────────────────────────────────────────────────────

  static Future<void> cacheReportsStatus(
      List<Map<String, dynamic>> reports) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    batch.delete('cached_reports_status');
    for (final report in reports) {
      batch.insert(
        'cached_reports_status',
        {
          'reportId': report['reportId'],
          'description': report['description'],
          'status': report['status'],
          'timestamp': report['timestamp'],
          'reportedBy': report['reportedBy'],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedReportsStatus() async {
    final db = await DBHelper.database;
    return db.query('cached_reports_status', orderBy: 'timestamp DESC');
  }

  // ────────────────────────────────────────────────────────────────
  // NEAREST HELP CENTERS (shelters)
  // ────────────────────────────────────────────────────────────────

  static Future<void> cacheShelters(List<Map<String, dynamic>> shelters) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    batch.delete('cached_shelters');
    for (final shelter in shelters) {
      batch.insert(
        'cached_shelters',
        {
          'docId': shelter['docId'],
          'name': shelter['name'],
          'type': shelter['type'],
          'location': shelter['location'],
          'capacity': shelter['capacity'],
          'occupied': shelter['occupied'],
          'lat': shelter['lat'],
          'lng': shelter['lng'],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedShelters() async {
    final db = await DBHelper.database;
    return db.query('cached_shelters');
  }

  // ────────────────────────────────────────────────────────────────
  // SAFETY TIPS
  // ────────────────────────────────────────────────────────────────

  static Future<void> cacheSafetyTips(List<Map<String, dynamic>> tips) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    batch.delete('cached_safety_tips');
    for (final tip in tips) {
      batch.insert(
        'cached_safety_tips',
        {
          'docId': tip['docId'],
          'title': tip['title'],
          'pdfUrl': tip['pdfUrl'],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedSafetyTips() async {
    final db = await DBHelper.database;
    return db.query('cached_safety_tips');
  }
}