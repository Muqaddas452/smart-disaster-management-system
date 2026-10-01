import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/rescue_team_model.dart';

class RescueTeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = "rescueTeams";
  final String _usersCollection = "rescueTeamUsers";

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
  //
  // Flips the team-level status in rescueTeams, then cascades
  // status: 'approved' into every rescueTeamUsers doc linked to
  // this team (leader + any members) so the Login screen, the
  // Pending Approval screen, and AuthWrapper all agree immediately.
  //
  // CHANGED: now wrapped so that if the cascade write is rejected by
  // Firestore Security Rules (permission-denied), you get a clear,
  // specific error instead of a silently-hanging Future — this is
  // exactly the failure mode that was leaving the admin's "Approve"
  // button stuck on its loading spinner with no feedback.
  //==========================================================

  Future<void> approveTeam(String id) async {
    final teamRef = _firestore.collection(_collection).doc(id);
    await teamRef.update({"status": "Available"});

    try {
      await _cascadeUserStatus(teamId: id, status: 'approved');
    } on FirebaseException catch (e) {
      // Surface exactly what Firestore said — 'permission-denied' here
      // means the Security Rules are blocking the write (rules not
      // deployed yet, or the isAdmin() check isn't matching this admin
      // account). Any other code points somewhere else entirely.
      // ignore: avoid_print
      print('approveTeam: cascade to rescueTeamUsers failed — '
          'code=${e.code}, message=${e.message}');
      rethrow; // let the calling screen's error handling react (e.g. stop the spinner, show a SnackBar)
    }
  }

  //==========================================================
  // REJECT TEAM
  // Pending -> Rejected
  // Same cascade idea as approveTeam(), for the reject path.
  //==========================================================

  Future<void> rejectTeam(String id) async {
    final teamRef = _firestore.collection(_collection).doc(id);
    await teamRef.update({"status": "Rejected"});

    try {
      await _cascadeUserStatus(teamId: id, status: 'rejected');
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('rejectTeam: cascade to rescueTeamUsers failed — '
          'code=${e.code}, message=${e.message}');
      rethrow;
    }
  }

  // Shared helper: updates the status field on every rescueTeamUsers
  // doc linked to this team (the leader, and any members who joined
  // before the team was approved/rejected).
  Future<void> _cascadeUserStatus({
    required String teamId,
    required String status,
  }) async {
    final linkedUsers = await _firestore
        .collection(_usersCollection)
        .where('teamId', isEqualTo: teamId)
        .get();

    if (linkedUsers.docs.isEmpty) {
      // ignore: avoid_print
      print('approveTeam/rejectTeam: no rescueTeamUsers doc found with '
          'teamId == $teamId — nothing to cascade. Double-check the '
          'teamId field actually matches this rescueTeams document id.');
      return;
    }

    final batch = _firestore.batch();
    for (final doc in linkedUsers.docs) {
      batch.update(doc.reference, {'status': status});
    }
    await batch.commit();
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