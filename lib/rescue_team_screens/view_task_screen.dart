import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smartdisaster/database/map_icon_helper.dart';
import 'enroute_tracking_service.dart';
import 'assign_members_screen.dart'; // Import assign members screen

class ViewTaskScreen extends StatefulWidget {
  final String taskId;

  const ViewTaskScreen({super.key, required this.taskId});

  @override
  State<ViewTaskScreen> createState() => _ViewTaskScreenState();
}

class _ViewTaskScreenState extends State<ViewTaskScreen> {
  static const Color kGreen = Color(0xFF1B5E38);
  String? _uid;
  String? _teamId; // Added to store leader's teamId
  bool _isLeader = false;
  bool _iconsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _precacheMapIcons();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;

    final doc = await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(_uid).get();
    final data = doc.data() ?? {};
    final role = data['role'] ?? '';
    if (mounted) {
      setState(() {
        _isLeader = data['isLeader'] == true || role == 'rescue_leader' || role == 'team_leader';
        _teamId = data['teamId']; // Fetch teamId from Firestore doc
      });
    }
  }

  Future<void> _precacheMapIcons() async {
    if (mounted) {
      setState(() {
        _iconsLoaded = true;
      });
    }
  }

  // --- TASK STATUS ACTIONS ---
  Future<void> _acceptTask() async {
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': 'accepted',
    });
  }

  // CHANGED: per-member status instead of the single shared task
  // `status` field. Previously, whichever member tapped "Mark as
  // Enroute" first flipped the WHOLE task's status to 'enroute' — every
  // other assigned member's button instantly (and wrongly) jumped to
  // "I've Arrived", even though they personally hadn't started moving
  // yet. Now each member's own progress lives at
  // `memberStatuses.{their uid}`, completely independent of everyone
  // else assigned to the same task. The task-level `status` field is
  // now only used for the leader's own pre-assignment stages
  // (dispatched/accepted/assigned) and the final 'resolved' state once
  // every assigned member has finished.
  Future<void> _markEnroute() async {
    await EnrouteTrackingService.instance.startTracking(widget.taskId);
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'memberStatuses.$_uid': 'enroute',
    });
  }

  Future<void> _startTask() async {
    // This member has arrived — stop THEIR OWN live movement tracking
    // (they're stationary at the task now). This only ever affects this
    // device's own tracking subscription, so it never interferes with
    // any other member who might still be enroute.
    await EnrouteTrackingService.instance.stopTracking();
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'memberStatuses.$_uid': 'in_progress',
    });
  }

  Future<void> _markCompleted() async {
    await EnrouteTrackingService.instance.stopTracking();
    // Clear only THIS member's dot — other assigned members' locations
    // (if they're still working the same task) must stay visible.
    if (_uid != null) {
      await EnrouteTrackingService.clearMemberLocation(widget.taskId, _uid!);
    }

    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
    await taskRef.update({'memberStatuses.$_uid': 'completed'});

    // If every assigned member has now completed their part, resolve
    // the whole task and clear any remaining location data.
    final snap = await taskRef.get();
    final data = snap.data() ?? {};
    final List assignedIds = List.from(data['assignedMemberIds'] ?? []);
    final Map memberStatuses = Map<String, dynamic>.from(data['memberStatuses'] ?? {});
    final bool allDone = assignedIds.isNotEmpty &&
        assignedIds.every((id) => memberStatuses[id] == 'completed');

    if (allDone) {
      await EnrouteTrackingService.clearAllMemberLocations(widget.taskId);
      await taskRef.update({'status': 'resolved'});
    }
  }

  Future<void> _showOverrideDialog(String currentStatus) async {
    const labels = {
      'enroute': 'Enroute',
      'in_progress': 'In Progress',
      'resolved': 'Resolved',
    };

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use this only if the assigned member cannot update their own status (e.g. unreachable). This bypasses the normal flow.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ...labels.keys.where((s) => s != currentStatus).map(
                  (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(labels[s]!),
                onTap: () => Navigator.pop(ctx, s),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (selected == null) return;
    await _forceUpdateStatus(selected);
  }

  // NOTE: this leader override still targets the overall task-level
  // `status` field, not an individual member's `memberStatuses` entry —
  // with multiple independent members, "override status" really needs
  // to ask WHICH member you're overriding. Left as-is for now since
  // that's a separate UI addition (a member picker); say the word and
  // I'll add it — it would replace 'resolved' below with per-member
  // logic like _markCompleted() uses.
  Future<void> _forceUpdateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': newStatus,
      'statusOverriddenBy': _uid,
      'statusOverriddenAt': FieldValue.serverTimestamp(),
    });
    if (newStatus == 'resolved') {
      await EnrouteTrackingService.clearAllMemberLocations(widget.taskId);
    }
  }

  Widget _overrideButton(String status) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => _showOverrideDialog(status),
        icon: const Icon(Icons.build_circle_outlined, size: 18, color: Colors.black54),
        label: const Text('Override status (emergency)',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        title: const Text('Task Details', style: TextStyle(color: Colors.white)),
        backgroundColor: kGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Task not found'));
          }

          final taskData = snapshot.data!.data()!;
          final String taskType = taskData['type'] ?? 'General';
          final String status = taskData['status'] ?? 'dispatched';
          final Map<String, dynamic> memberStatuses =
          Map<String, dynamic>.from(taskData['memberStatuses'] ?? {});

          // Safety net now checks THIS member's own status, not the
          // shared task status — tracking should stop for this device
          // only once THIS member is no longer enroute, regardless of
          // what other assigned members are doing.
          final String myStatus = (_uid != null ? memberStatuses[_uid] : null) ?? 'assigned';
          EnrouteTrackingService.instance.stopIfTaskNoLongerEnroute(widget.taskId, myStatus);

          // FIXED: task documents store coordinates as `lat` / `lng`, but this
          // used to read `latitude` / `longitude` — fields that don't exist on
          // a task doc — so it always silently fell back to the default point
          // below and showed the incident in the wrong place. Both spellings
          // are accepted now.
          final double lat = ((taskData['lat'] ?? taskData['latitude'] ?? 32.4274) as num).toDouble();
          final double lng = ((taskData['lng'] ?? taskData['longitude'] ?? 73.5693) as num).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(taskData['priority'] ?? 'high').toString().toLowerCase()} priority',
                            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Emergency: ${taskData['type'] ?? taskData['title'] ?? 'Alert'}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 12),
                        const Text('DESCRIPTION', style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(taskData['description'] ?? 'No description provided.'),
                        const SizedBox(height: 12),
                        const Text('LOCATION', style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.teal.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(taskData['address'] ?? 'Address Unavailable', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.black45, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('LIVE TRACKING', style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Container(
                  height: 220,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: _buildLiveTrackingMap(taskData, taskType, lat, lng),
                ),

                const SizedBox(height: 16),
                const Text('ASSIGNED TEAM MEMBERS', style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                _buildMemberList(taskData, memberStatuses),

                const SizedBox(height: 12),

                _buildLiveStatusCard(status, taskData, memberStatuses),

                const SizedBox(height: 20),

                _buildActionButtons(status, taskData, memberStatuses, myStatus),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTrackingMap(Map<String, dynamic> taskData, String taskType, double lat, double lng) {
    return FutureBuilder<Set<Marker>>(
      future: _buildMarkersList(taskData, taskType, lat, lng),
      builder: (context, snapshot) {
        final markers = snapshot.data ?? {};

        return GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 13),
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        );
      },
    );
  }
  // Helper function to build markers asynchronously without cache errors
  Future<Set<Marker>> _buildMarkersList(Map<String, dynamic> taskData, String taskType, double lat, double lng) async {
    final Set<Marker> markers = {};
    final Map<String, dynamic> memberLocations = Map<String, dynamic>.from(taskData['memberLocations'] ?? {});
    final List assignedMembers = taskData['assignedMembers'] ?? [];

    // NOTE: Task/Incident marker ko yahan se hata diya gaya hai
    // kyun ke task ki location pehle hi Map screen ke Tasks tab par show hoti hai.

    // Dynamic Team Members Live Location Markers with Name
    final memberIcon = await createDirectIconMarker(Icons.person, Colors.blue.shade700, size: 50);

    memberLocations.forEach((uid, locData) {
      if (locData is Map && locData.containsKey('lat') && locData.containsKey('lng')) {
        final double memberLat = (locData['lat'] as num).toDouble();
        final double memberLng = (locData['lng'] as num).toDouble();

        // Assigned members list se us member ka naam dhoondna
        String memberName = 'Team Member';
        for (var m in assignedMembers) {
          if (m is Map && (m['uid'] == uid || m['id'] == uid)) {
            memberName = m['name'] ?? 'Team Member';
            break;
          }
        }

        markers.add(
          Marker(
            markerId: MarkerId('member_$uid'),
            position: LatLng(memberLat, memberLng),
            icon: memberIcon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
              title: memberName, // Member ka real name show hoga
              snippet: 'Enroute / On Location',
            ),
          ),
        );
      }
    });

    return markers;
  }

  // CHANGED: now also shows each member's individual status (from
  // `memberStatuses`) next to their name, instead of just a plain name
  // list — this is the "leader can see each member's status
  // individually" part of the fix.
  Widget _buildMemberList(Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    final List assignedMembers = taskData['assignedMembers'] ?? [];
    if (assignedMembers.isEmpty) {
      return const Text('No team members assigned yet.', style: TextStyle(color: Colors.black45));
    }

    String labelFor(String? statusValue) {
      switch (statusValue) {
        case 'enroute':
          return 'Enroute';
        case 'in_progress':
          return 'In Progress';
        case 'completed':
          return 'Completed';
        default:
          return 'Assigned';
      }
    }

    Color colorFor(String? statusValue) {
      switch (statusValue) {
        case 'enroute':
          return Colors.orange.shade700;
        case 'in_progress':
          return Colors.blue.shade700;
        case 'completed':
          return kGreen;
        default:
          return Colors.black45;
      }
    }

    return Column(
      children: assignedMembers.map((m) {
        final name = m is Map ? (m['name'] ?? 'Member') : m.toString();
        final String? memberUid = m is Map ? (m['uid'] ?? m['id']) as String? : null;
        final String? memberStatus = memberUid != null ? memberStatuses[memberUid] as String? : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal.shade50,
                radius: 16,
                child: Icon(Icons.person, color: Colors.teal.shade700, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (memberUid != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorFor(memberStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labelFor(memberStatus),
                    style: TextStyle(color: colorFor(memberStatus), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // CHANGED: once the task has been assigned to members, this now shows
  // an aggregate summary built from `memberStatuses` (e.g. "1 of 3
  // members completed") instead of one generic sentence that implied a
  // single assigned member.
  Widget _buildLiveStatusCard(
      String status, Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    String message = '';
    Color cardColor = Colors.white;
    Color textColor = Colors.black87;

    if (status == 'assigned') {
      final List assignedIds = List.from(taskData['assignedMemberIds'] ?? []);
      final int total = assignedIds.length;
      final int completed = assignedIds.where((id) => memberStatuses[id] == 'completed').length;
      final int inProgress = assignedIds.where((id) => memberStatuses[id] == 'in_progress').length;
      final int enroute = assignedIds.where((id) => memberStatuses[id] == 'enroute').length;

      if (total == 0) return const SizedBox.shrink();

      if (completed == total) {
        message = 'All $total members have completed this task';
        cardColor = Colors.green.shade50;
        textColor = kGreen;
      } else if (enroute + inProgress + completed == 0) {
        message = 'Waiting for assigned members to start';
        cardColor = Colors.white;
        textColor = Colors.black54;
      } else {
        message = '$completed of $total completed'
            '${inProgress > 0 ? ' · $inProgress in progress' : ''}'
            '${enroute > 0 ? ' · $enroute enroute' : ''}';
        cardColor = Colors.blue.shade50;
        textColor = Colors.blue.shade900;
      }
    } else {
      switch (status) {
        case 'resolved':
        case 'completed':
          message = 'Task completed successfully by assigned team';
          cardColor = Colors.green.shade50;
          textColor = kGreen;
          break;
        default:
          return const SizedBox.shrink();
      }
    }

    final bool overridden = taskData['statusOverriddenBy'] != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          if (overridden) ...[
            const SizedBox(height: 4),
            const Text('Manually updated by team leader',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  // CHANGED: the member-facing branch now reads `myStatus`
  // (this member's own entry in `memberStatuses`) instead of the
  // shared task-level `status` — so each assigned member sees the
  // button matching THEIR OWN progress, independent of what other
  // members assigned to the same task are doing.
  Widget _buildActionButtons(
      String status,
      Map<String, dynamic> taskData,
      Map<String, dynamic> memberStatuses,
      String myStatus,
      ) {
    if (_isLeader) {
      if (status == 'dispatched') {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _acceptTask,
            child: const Text('Accept Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
      if (status == 'accepted' || status == 'assigned') {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: Text(status == 'assigned' ? 'Reassign Members' : 'Assign to Team Members', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (_teamId == null || _teamId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Team ID not found for this leader.')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignMembersScreen(
                        taskId: widget.taskId,
                        teamId: _teamId!,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (status == 'assigned') ...[
              const SizedBox(height: 8),
              _overrideButton(status),
            ],
          ],
        );
      }
      if (status == 'assigned') {
        return _overrideButton(status);
      }
    } else {
      final List assignedMemberIds = taskData['assignedMemberIds'] ?? [];
      if (assignedMemberIds.contains(_uid) && status == 'assigned') {
        if (myStatus == 'assigned') {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.navigation, color: Colors.white),
              label: const Text('Mark as Enroute', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _markEnroute,
            ),
          );
        }
        if (myStatus == 'enroute') {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: const Text("I've Arrived – Start Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _startTask,
            ),
          );
        }
        if (myStatus == 'in_progress') {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Mark Task Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _markCompleted,
            ),
          );
        }
        if (myStatus == 'completed') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: kGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "You've completed your part of this task",
              textAlign: TextAlign.center,
              style: TextStyle(color: kGreen, fontWeight: FontWeight.bold),
            ),
          );
        }
      }
    }

    return const SizedBox.shrink();
  }
}