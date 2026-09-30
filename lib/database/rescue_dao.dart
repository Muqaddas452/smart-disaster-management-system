import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// Data Access Object for the Rescue side (leader + member):
/// profile, tasks, and the home screen's live alert banner.
/// This file does NOT create tables — DBHelper already did that.
/// It only knows how to insert/read rows in those tables.
class RescueDao {
  // ────────────────────────────────────────────────────────────────
  // RESCUE PROFILE (leader or member — same table for both)
  // ────────────────────────────────────────────────────────────────

  static Future<void> cacheProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String emergencyContact,
    required String personalAddress,
    required String specialization,
    required String bloodGroup,
    required String teamName,
    required String teamId,
    required String officialAddress,
    required String role,
    required bool isLeader,
    required String photoUrl,
    required String createdAt,
  }) async {
    final db = await DBHelper.database;
    await db.insert(
      'cached_rescue_profile',
      {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'emergencyContact': emergencyContact,
        'personalAddress': personalAddress,
        'specialization': specialization,
        'bloodGroup': bloodGroup,
        'teamName': teamName,
        'teamId': teamId,
        'officialAddress': officialAddress,
        'role': role,
        'isLeader': isLeader ? 1 : 0,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getCachedProfile(String uid) async {
    final db = await DBHelper.database;
    final rows = await db.query(
      'cached_rescue_profile',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  // ────────────────────────────────────────────────────────────────
  // TASKS (shared by leader's full team list and member's assigned list)
  // ────────────────────────────────────────────────────────────────

  /// Caches the full current task list, replacing whatever was cached
  /// before. Simple and correct since only one user is ever logged in on
  /// a given device, so there is only ever one relevant task list to cache.
  static Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    batch.delete('cached_tasks');
    for (final task in tasks) {
      batch.insert(
        'cached_tasks',
        {
          'taskId': task['taskId'],
          'type': task['type'],
          'priority': task['priority'],
          'address': task['address'],
          'description': task['description'],
          'status': task['status'],
          'teamId': task['teamId'],
          'assignedMemberIds': DBHelper.encodeList(task['assignedMemberIds'] ?? []),
          'assignedMembers': DBHelper.encodeList(task['assignedMembers'] ?? []),
          'latitude': task['latitude'],
          'longitude': task['longitude'],
          'createdAt': task['createdAt'],
          'statusOverriddenBy': task['statusOverriddenBy'],
          'statusOverriddenAt': task['statusOverriddenAt'],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedTasks() async {
    final db = await DBHelper.database;
    final rows = await db.query('cached_tasks', orderBy: 'createdAt DESC');
    // Decode the JSON-encoded list fields back into real Lists before
    // handing the data back to the UI.
    return rows.map((row) {
      final copy = Map<String, dynamic>.from(row);
      copy['assignedMemberIds'] = DBHelper.decodeList(row['assignedMemberIds'] as String?);
      copy['assignedMembers'] = DBHelper.decodeList(row['assignedMembers'] as String?);
      return copy;
    }).toList();
  }

  /// Inserts/updates only the given tasks WITHOUT clearing the table first.
  /// Use this for partial task streams (e.g. the home screen's "high
  /// priority only" query) so it doesn't wipe out the full list that
  /// TasksListScreen has already cached. cacheTasks() (above) is for the
  /// full authoritative list only.
  static Future<void> upsertTasks(List<Map<String, dynamic>> tasks) async {
    final db = await DBHelper.database;
    final batch = db.batch();
    for (final task in tasks) {
      batch.insert(
        'cached_tasks',
        {
          'taskId': task['taskId'],
          'type': task['type'],
          'priority': task['priority'],
          'address': task['address'],
          'description': task['description'],
          'status': task['status'],
          'teamId': task['teamId'],
          'assignedMemberIds': DBHelper.encodeList(task['assignedMemberIds'] ?? []),
          'assignedMembers': DBHelper.encodeList(task['assignedMembers'] ?? []),
          'latitude': task['latitude'],
          'longitude': task['longitude'],
          'createdAt': task['createdAt'],
          'statusOverriddenBy': task['statusOverriddenBy'],
          'statusOverriddenAt': task['statusOverriddenAt'],
          'updatedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Reads cached tasks filtered to high priority, not-yet-resolved ones —
  /// used by the home screen's "Urgent Tasks" section.
  static Future<List<Map<String, dynamic>>> getCachedUrgentTasks() async {
    final all = await getCachedTasks();
    return all
        .where((t) =>
    (t['priority'] ?? '').toString().toLowerCase() == 'high' &&
        (t['status'] ?? '') != 'resolved')
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  // RESCUE HOME SCREEN — "latest active alert" banner (single row)
  // ────────────────────────────────────────────────────────────────

  static Future<void> cacheLiveAlert({
    required String title,
    required String message,
    required String riskLevel,
    required double latitude,
    required double longitude,
    required String createdAt,
  }) async {
    final db = await DBHelper.database;
    await db.insert(
      'cached_rescue_live_alert',
      {
        'id': 1, // fixed id — we only ever keep one row
        'title': title,
        'message': message,
        'riskLevel': riskLevel,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAt,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getCachedLiveAlert() async {
    final db = await DBHelper.database;
    final rows = await db.query('cached_rescue_live_alert', where: 'id = 1');
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> clearCachedLiveAlert() async {
    final db = await DBHelper.database;
    await db.delete('cached_rescue_live_alert');
  }
}