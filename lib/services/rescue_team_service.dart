import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/rescue_team_model.dart';

class RescueTeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = "rescueTeams";

  //==========================================================
  // GET ALL TEAMS
  //==========================================================

  Stream<List<RescueTeam>> getRescueTeams() {
    return _firestore
        .collection(_collection)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => RescueTeam.fromFirestore(doc))
          .toList(),
    );
  }

  //==========================================================
  // GET SINGLE TEAM
  //==========================================================

  Stream<RescueTeam> getRescueTeam(String id) {
    return _firestore
        .collection(_collection)
        .doc(id)
        .snapshots()
        .map((doc) => RescueTeam.fromFirestore(doc));
  }

  //==========================================================
  // ADD TEAM
  //==========================================================

  Future<void> addRescueTeam(RescueTeam team) async {
    await _firestore.collection(_collection).add(team.toMap());
  }

  //==========================================================
  // UPDATE TEAM
  //==========================================================

  Future<void> updateRescueTeam(RescueTeam team) async {
    await _firestore
        .collection(_collection)
        .doc(team.id)
        .update(team.toMap());
  }

  //==========================================================
  // DELETE TEAM
  //==========================================================

  Future<void> deleteRescueTeam(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  //==========================================================
  // APPROVE TEAM
  // Pending -> Available
  //==========================================================

  Future<void> approveTeam(String id) async {
    await _firestore.collection(_collection).doc(id).update({
      "status": "Available",
    });
  }

  //==========================================================
  // DISPATCH TEAM
  // Available -> On Mission
  //==========================================================

  Future<void> dispatchTeam({
    required String teamId,
    required String reportId,
    required String area,
  }) async {
    await _firestore.collection(_collection).doc(teamId).update({
      "status": "On Mission",
      "assignedReportId": reportId,
      "assignedArea": area,
      "dispatchTime": FieldValue.serverTimestamp(),
    });
  }

  //==========================================================
  // COMPLETE MISSION
  // On Mission -> Available
  //==========================================================

  Future<void> completeMission(
      String teamId,
      String reportId,
      ) async {

    // Make rescue team available again
    await _firestore
        .collection(_collection)
        .doc(teamId)
        .update({

      "status": "Available",

      "assignedReportId": "",

      "assignedArea": "",

      "arrivalTime": FieldValue.serverTimestamp(),

    });

    // Mark report as resolved
    await _firestore
        .collection("manual_reports")
        .doc(reportId)
        .update({

      "status": "Resolved",

    });

  }

  //==========================================================
  // UPDATE GPS LOCATION
  //==========================================================

  Future<void> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore.collection(_collection).doc(id).update({
      "latitude": latitude,
      "longitude": longitude,
    });
  }

  //==========================================================
  // TOTAL TEAMS
  //==========================================================

  Stream<int> totalTeams() {
    return getRescueTeams().map((teams) => teams.length);
  }

  //==========================================================
  // PENDING
  //==========================================================

  Stream<int> pendingTeams() {
    return getRescueTeams().map(
          (teams) => teams.where((t) => t.status == "Pending").length,
    );
  }

  //==========================================================
  // AVAILABLE
  //==========================================================

  Stream<int> availableTeams() {
    return getRescueTeams().map(
          (teams) => teams.where((t) => t.status == "Available").length,
    );
  }

  //==========================================================
  // ON MISSION
  //==========================================================

  Stream<int> missionTeams() {
    return getRescueTeams().map(
          (teams) => teams.where((t) => t.status == "On Mission").length,
    );
  }

  //==========================================================
  // OFFLINE (Optional)
  //==========================================================

  Stream<int> offlineTeams() {
    return getRescueTeams().map(
          (teams) => teams.where((t) => t.status == "Offline").length,
    );
  }

  //==========================================================
  // BUSY (Compatibility)
  //==========================================================

  Stream<int> busyTeams() {
    return missionTeams();
  }
}