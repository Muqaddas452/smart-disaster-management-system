import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access and write operations for Rescue Tasks.
class RescueTaskService {
  RescueTaskService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('manual_reports');

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection('rescueTeams');

  Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream() {
    return _tasks.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reportsStream() {
    return _reports.orderBy('timestamp', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> teamsStream() {
    return _teams.snapshots();
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  String _stringValue(dynamic value, [String fallback = '']) {
    return (value ?? fallback).toString();
  }

  String _normalizeStatus(dynamic value) {
    return _stringValue(value).trim().toLowerCase().replaceAll(' ', '_');
  }

  bool _isTeamAvailable(Map<String, dynamic> teamData) {
    return _normalizeStatus(teamData['status']) == 'available';
  }

  String _reportStatusForTask(String taskStatus) {
    switch (_normalizeStatus(taskStatus)) {
      case 'dispatched':
      case 'assigned':
        return 'assigned';

      case 'accepted':
      case 'enroute':
      case 'in_progress':
      case 'in progress':
      case 'started':
        return 'in_progress';

      case 'resolved':
      case 'complete':
      case 'completed':
        return 'resolved';

      default:
        return 'assigned';
    }
  }

  // ------------------------------------------------------------
  // Create a manual task from the admin panel
  // ------------------------------------------------------------

  Future<void> createManualTask({
    required String teamId,
    required String emergencyType,
    required String description,
    required String priority,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final teamRef = _teams.doc(teamId);
    final taskRef = _tasks.doc();

    await _firestore.runTransaction((transaction) async {
      // Read first.
      final teamSnapshot = await transaction.get(teamRef);

      if (!teamSnapshot.exists) {
        throw StateError('Rescue Team ID "$teamId" was not found.');
      }

      final teamData = teamSnapshot.data() ?? <String, dynamic>{};

      if (!_isTeamAvailable(teamData)) {
        throw StateError(
          'This rescue team is not available. Current status: '
              '${teamData['status'] ?? 'Unknown'}.',
        );
      }

      final teamName =
      _stringValue(teamData['teamName'], 'Rescue Team');
      final leaderId = _stringValue(teamData['leaderId'], teamId);
      final leaderName =
      _stringValue(teamData['leaderName'], 'Rescue Leader');
      final leaderPhone = _stringValue(teamData['phoneNumber']);

      final now = FieldValue.serverTimestamp();

      final taskData = <String, dynamic>{
        'taskId': taskRef.id,
        'reportId': null,
        'sourceType': 'admin_manual',
        'sourceId': 'admin',
        'citizenId': '',
        'citizenName': '',
        'phoneNumber': '',
        'emergencyType': emergencyType,
        'description': description,
        'priority': priority,
        'severity': priority,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'location': address,
        'city': '',
        'imageUrl': '',
        'teamId': teamId,
        'teamName': teamName,
        'leaderId': leaderId,
        'leaderName': leaderName,
        'leaderPhone': leaderPhone,
        'assignedMemberIds': <String>[],
        'assignedMembers': <Map<String, dynamic>>[],
        'status': 'dispatched',
        'createdAt': now,
        'assignedAt': now,
        'acceptedAt': null,
        'enrouteAt': null,
        'startedAt': null,
        'resolvedAt': null,
        'lastUpdated': now,
      };

      // Writes after all reads.
      transaction.set(taskRef, taskData);

      transaction.update(teamRef, {
        'status': 'On Mission',
        'assignedReportId': null,
        'assignedTaskId': taskRef.id,
        'assignedArea': address,
        'lastUpdated': now,
      });
    });
  }

  // ------------------------------------------------------------
  // Assign a citizen report to a rescue team
  // ------------------------------------------------------------

  Future<void> assignReportToTeam(
      QueryDocumentSnapshot<Map<String, dynamic>> report,
      QueryDocumentSnapshot<Map<String, dynamic>> team,
      ) async {
    final reportRef = _reports.doc(report.id);
    final teamRef = _teams.doc(team.id);
    final taskRef = _tasks.doc();

    await _firestore.runTransaction((transaction) async {
      // Read all documents before writing.
      final reportSnapshot = await transaction.get(reportRef);
      final teamSnapshot = await transaction.get(teamRef);

      if (!reportSnapshot.exists) {
        throw StateError('The selected report no longer exists.');
      }

      if (!teamSnapshot.exists) {
        throw StateError('The selected rescue team no longer exists.');
      }

      final reportData =
          reportSnapshot.data() ?? <String, dynamic>{};
      final teamData = teamSnapshot.data() ?? <String, dynamic>{};

      if (!_isTeamAvailable(teamData)) {
        throw StateError(
          'This rescue team is not available. Current status: '
              '${teamData['status'] ?? 'Unknown'}.',
        );
      }

      final now = FieldValue.serverTimestamp();

      final teamName =
      _stringValue(teamData['teamName'], 'Rescue Team');
      final leaderId = _stringValue(teamData['leaderId']);
      final leaderName =
      _stringValue(teamData['leaderName'], 'Rescue Leader');

      final taskData = <String, dynamic>{
        'taskId': taskRef.id,
        'reportId': report.id,
        'sourceType': 'citizen_report',
        'sourceId': report.id,
        'citizenId': reportData['citizenId'] ?? '',
        'citizenName': reportData['reporterName'] ?? 'Citizen',
        'phoneNumber': reportData['phoneNumber'] ?? '',
        'emergencyType': reportData['emergencyType'] ?? 'Emergency',
        'description': reportData['description'] ?? '',
        'severity': reportData['severity'] ?? 'Unknown',
        'latitude': reportData['latitude'],
        'longitude': reportData['longitude'],
        'city': reportData['city'] ?? reportData['location'] ?? 'Unknown',
        'location': reportData['location'] ?? '',
        'imageUrl': reportData['imageUrl'] ?? '',
        'teamId': team.id,
        'teamName': teamName,
        'leaderId': leaderId,
        'leaderName': leaderName,
        'leaderPhone': teamData['phoneNumber'] ?? '',
        'assignedMemberIds': <String>[],
        'assignedMembers': <Map<String, dynamic>>[],
        'status': 'dispatched',
        'createdAt': now,
        'assignedAt': now,
        'acceptedAt': null,
        'enrouteAt': null,
        'startedAt': null,
        'resolvedAt': null,
        'lastUpdated': now,
      };

      // All writes are in the same transaction.
      transaction.set(taskRef, taskData);

      transaction.update(reportRef, {
        'taskId': taskRef.id,
        'assignedTeamId': team.id,
        'assignedTeamName': teamName,
        'assignedLeaderId': leaderId,
        'assignedLeaderName': leaderName,
        'status': 'assigned',
        'assignedAt': now,
      });

      transaction.update(teamRef, {
        'status': 'On Mission',
        'assignedReportId': report.id,
        'assignedTaskId': taskRef.id,
        'assignedArea':
        reportData['city'] ?? reportData['location'] ?? '',
        'lastUpdated': now,
      });
    });
  }

  // ------------------------------------------------------------
  // Assign a team to an existing task
  // ------------------------------------------------------------

  Future<void> assignTeamToExistingTask(
      QueryDocumentSnapshot<Map<String, dynamic>> task,
      QueryDocumentSnapshot<Map<String, dynamic>> team,
      ) async {
    final taskRef = _tasks.doc(task.id);
    final teamRef = _teams.doc(team.id);

    await _firestore.runTransaction((transaction) async {
      // Read all documents before writing.
      final taskSnapshot = await transaction.get(taskRef);
      final teamSnapshot = await transaction.get(teamRef);

      if (!taskSnapshot.exists) {
        throw StateError('The selected task no longer exists.');
      }

      if (!teamSnapshot.exists) {
        throw StateError('The selected rescue team no longer exists.');
      }

      final taskData = taskSnapshot.data() ?? <String, dynamic>{};
      final teamData = teamSnapshot.data() ?? <String, dynamic>{};

      if (!_isTeamAvailable(teamData)) {
        throw StateError(
          'This rescue team is not available. Current status: '
              '${teamData['status'] ?? 'Unknown'}.',
        );
      }

      final reportId = _stringValue(taskData['reportId']);
      DocumentReference<Map<String, dynamic>>? reportRef;
      DocumentSnapshot<Map<String, dynamic>>? reportSnapshot;

      // If this task belongs to a citizen report, read it before writes.
      if (reportId.isNotEmpty) {
        reportRef = _reports.doc(reportId);
        reportSnapshot = await transaction.get(reportRef);
      }

      final now = FieldValue.serverTimestamp();
      final teamName =
      _stringValue(teamData['teamName'], 'Rescue Team');
      final leaderId = _stringValue(teamData['leaderId']);
      final leaderName =
      _stringValue(teamData['leaderName'], 'Rescue Leader');

      transaction.update(taskRef, {
        'teamId': team.id,
        'teamName': teamName,
        'leaderId': leaderId,
        'leaderName': leaderName,
        'leaderPhone': teamData['phoneNumber'] ?? '',
        'status': 'dispatched',
        'assignedAt': now,
        'lastUpdated': now,
      });

      transaction.update(teamRef, {
        'status': 'On Mission',
        'assignedReportId': reportId.isEmpty ? null : reportId,
        'assignedTaskId': task.id,
        'assignedArea':
        taskData['city'] ?? taskData['location'] ?? '',
        'lastUpdated': now,
      });

      if (reportRef != null &&
          reportSnapshot != null &&
          reportSnapshot.exists) {
        transaction.update(reportRef, {
          'assignedTeamId': team.id,
          'assignedTeamName': teamName,
          'assignedLeaderId': leaderId,
          'assignedLeaderName': leaderName,
          'status': 'assigned',
          'assignedAt': now,
        });
      }
    });
  }

  // ------------------------------------------------------------
  // Update task status and synchronize its report/team
  // ------------------------------------------------------------

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final taskRef = _tasks.doc(taskId);

    await _firestore.runTransaction((transaction) async {
      // Read task first.
      final taskSnapshot = await transaction.get(taskRef);

      if (!taskSnapshot.exists) {
        throw StateError('Task "$taskId" was not found.');
      }

      final taskData = taskSnapshot.data() ?? <String, dynamic>{};
      final reportId = _stringValue(taskData['reportId']);
      final teamId = _stringValue(taskData['teamId']);

      DocumentReference<Map<String, dynamic>>? reportRef;
      DocumentSnapshot<Map<String, dynamic>>? reportSnapshot;

      DocumentReference<Map<String, dynamic>>? teamRef;
      DocumentSnapshot<Map<String, dynamic>>? teamSnapshot;

      // Complete every read before performing any writes.
      if (reportId.isNotEmpty) {
        reportRef = _reports.doc(reportId);
        reportSnapshot = await transaction.get(reportRef);
      }

      if (teamId.isNotEmpty) {
        teamRef = _teams.doc(teamId);
        teamSnapshot = await transaction.get(teamRef);
      }

      final normalizedStatus = _normalizeStatus(status);
      final now = FieldValue.serverTimestamp();

      final taskUpdates = <String, dynamic>{
        'status': normalizedStatus,
        'lastUpdated': now,
      };

      if (normalizedStatus == 'accepted') {
        taskUpdates['acceptedAt'] = now;
      } else if (normalizedStatus == 'enroute') {
        taskUpdates['enrouteAt'] = now;
      } else if (normalizedStatus == 'in_progress') {
        taskUpdates['startedAt'] = now;
      } else if (normalizedStatus == 'resolved' ||
          normalizedStatus == 'complete' ||
          normalizedStatus == 'completed') {
        taskUpdates['status'] = 'resolved';
        taskUpdates['resolvedAt'] = now;
      }

      transaction.update(taskRef, taskUpdates);

      // Synchronize the linked manual report, if it still exists.
      if (reportRef != null &&
          reportSnapshot != null &&
          reportSnapshot.exists) {
        transaction.update(reportRef, {
          'status': _reportStatusForTask(normalizedStatus),
          'lastUpdated': now,
        });
      }

      // Keep the team assigned until the task is resolved.
      final isResolved = normalizedStatus == 'resolved' ||
          normalizedStatus == 'complete' ||
          normalizedStatus == 'completed';

      if (teamRef != null &&
          teamSnapshot != null &&
          teamSnapshot.exists) {
        final currentTeamData =
            teamSnapshot.data() ?? <String, dynamic>{};

        // Do not release a team if it has since been assigned
        // to a different task.
        if (_stringValue(currentTeamData['assignedTaskId']) == taskId) {
          if (isResolved) {
            transaction.update(teamRef, {
              'status': 'Available',
              'assignedTaskId': FieldValue.delete(),
              'assignedReportId': FieldValue.delete(),
              'lastUpdated': now,
            });
          } else {
            transaction.update(teamRef, {
              'status': 'On Mission',
              'lastUpdated': now,
            });
          }
        }
      }
    });
  }
}