// lib/services/report_sync_service.dart
// Internet aane par SQLite reports automatically Firestore ko sync karta hai

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/db_report_helper.dart';

class ReportSyncService {
  // ── Ek baar manually sync trigger karna (app open hone par call karo)
  static Future<SyncResult> syncPendingReports() async {
    try {
      // 1. Internet check karo
      final connectivityResult = await Connectivity().checkConnectivity();
      // List check — connectivity_plus 6.x+ mein list return hoti hai
      final isOnline = connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (!isOnline) {
        return SyncResult(
          success: false,
          message: 'No internet connection. Will retry when online.',
          syncedCount: 0,
        );
      }

      // 2. Unsynced local reports lao
      final unsyncedReports = await DBReportHelper.getUnsyncedReports();

      if (unsyncedReports.isEmpty) {
        return SyncResult(
          success: true,
          message: 'All reports already synced.',
          syncedCount: 0,
        );
      }

      // 3. Har report Firestore mein bhejo
      final firestore = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      int syncedCount = 0;
      List<String> failedIds = [];

      for (final report in unsyncedReports) {
        try {
          await firestore.collection('manual_reports').add({
            'name': report['name'],
            'phone': report['phone'],
            'incident_type': report['emergencyType'],   // Firebase field name match
            'description': report['description'],
            'severity_level': report['severity'],        // Firebase field name match
            'location': report['location'],
            'latitude': report['latitude'],
            'longitude': report['longitude'],
            'timestamp': FieldValue.serverTimestamp(),   // Firebase ka proper timestamp
            'localTimestamp': report['timestamp'],       // original local time b rakhte hain
            'reportedBy': uid,
            'status': 'Pending',
            'syncedFromOffline': true,                   // identify karne k liye k offline tha
          });

          // 4. Successfully sync hua to local DB mein mark karo
          await DBReportHelper.markAsSynced(report['id'] as int);
          syncedCount++;
        } catch (e) {
          // Ek report fail ho to baaki continue karo
          failedIds.add(report['id'].toString());
        }
      }

      // 5. Synced reports cleanup (optional — comment out karo agar history chahiye)
      await DBReportHelper.deleteSyncedReports();

      if (failedIds.isEmpty) {
        return SyncResult(
          success: true,
          message: '$syncedCount report(s) successfully synced to Firebase!',
          syncedCount: syncedCount,
        );
      } else {
        return SyncResult(
          success: false,
          message: '$syncedCount synced, ${failedIds.length} failed. Will retry.',
          syncedCount: syncedCount,
        );
      }
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Sync error: $e',
        syncedCount: 0,
      );
    }
  }

  // ── Connectivity stream — jaise hi internet aaye, auto sync
  // Is stream ko main.dart ya App widget mein listen karo
  static Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;
}

// ── Sync result model — result show karne k liye
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
  });
}
