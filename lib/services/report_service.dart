import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final String _collection = "manual_reports";

  // ==========================================================
  // GET ALL REPORTS
  // ==========================================================

  Stream<List<Report>> getReports() {
    return _firestore
        .collection(_collection)
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => Report.fromFirestore(doc))
          .toList(),
    );
  }

  // ==========================================================
  // GET SINGLE REPORT
  // ==========================================================

  Stream<Report> getReport(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map(
          (doc) => Report.fromFirestore(doc),
    );
  }

  // ==========================================================
  // UPDATE STATUS MANUALLY
  // ==========================================================

  Future<void> updateStatus(
      String reportId,
      String status,
      ) async {
    await _firestore
        .collection(_collection)
        .doc(reportId)
        .update({
      "status": status,
    });
  }

  // ==========================================================
  // ASSIGN REPORT TO RESCUE TEAM
  // ==========================================================
  //
  // When a rescue team is dispatched, the report should
  // automatically become "In Progress".
  //
  // Do NOT use "Assigned" here because your report UI
  // already uses "In Progress" as the working status.
  //

  Future<void> assignReport(String reportId) async {
    await _firestore
        .collection(_collection)
        .doc(reportId)
        .update({
      "status": "In Progress",
    });
  }

  // ==========================================================
  // COMPLETE REPORT
  // ==========================================================

  Future<void> completeReport(String reportId) async {
    await _firestore
        .collection(_collection)
        .doc(reportId)
        .update({
      "status": "Resolved",
    });
  }

  // ==========================================================
  // DELETE REPORT
  // ==========================================================

  Future<void> deleteReport(String reportId) async {
    await _firestore
        .collection(_collection)
        .doc(reportId)
        .delete();
  }

  // ==========================================================
  // TOTAL REPORTS
  // ==========================================================

  Stream<int> totalReports() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.length,
    );
  }

  // ==========================================================
  // PENDING REPORTS
  // ==========================================================

  Stream<int> pendingReports() {
    return _firestore
        .collection(_collection)
        .where(
      "status",
      isEqualTo: "Pending",
    )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.length,
    );
  }

  // ==========================================================
  // IN PROGRESS REPORTS
  // ==========================================================

  Stream<int> inProgressReports() {
    return _firestore
        .collection(_collection)
        .where(
      "status",
      isEqualTo: "In Progress",
    )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.length,
    );
  }

  // ==========================================================
  // ASSIGNED REPORTS
  // ==========================================================
  //
  // Keep this only if your old Firestore data contains
  // "Assigned" reports.
  //

  Stream<int> assignedReports() {
    return _firestore
        .collection(_collection)
        .where(
      "status",
      isEqualTo: "Assigned",
    )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.length,
    );
  }

  // ==========================================================
  // RESOLVED REPORTS
  // ==========================================================

  Stream<int> resolvedReports() {
    return _firestore
        .collection(_collection)
        .where(
      "status",
      isEqualTo: "Resolved",
    )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.length,
    );
  }
}