import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_disaster_management_system/database/map_icon_helper.dart';
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
    try {
      markerIconCache['member'] = await createCustomMarkerIcon(
        Icons.person,
        Colors.blue.shade700,
        Colors.white,
      );
    } catch (e) {
      debugPrint("Error loading member icon: $e");
    }
    if (mounted) {
      setState(() {
        _iconsLoaded = true;
      });
    }
  }

  Future<void> _loadTaskTypeIcon(String taskType) async {
    if (!markerIconCache.containsKey(taskType)) {
      try {
        markerIconCache[taskType] = await createCustomMarkerIcon(
          getTaskTypeIcon(taskType),
          Colors.red.shade700,
          Colors.white,
        );
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint("Error loading task icon: $e");
      }
    }
  }

  // --- TASK STATUS ACTIONS ---
  Future<void> _acceptTask() async {
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': 'accepted',
    });
  }

  Future<void> _markEnroute() async {
    await EnrouteTrackingService.instance.startTracking(widget.taskId);
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': 'enroute',
    });
  }

  Future<void> _startTask() async {
    await EnrouteTrackingService.instance.stopTracking();
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': 'in_progress',
    });
  }

  Future<void> _markCompleted() async {
    await EnrouteTrackingService.instance.stopTracking();
    await EnrouteTrackingService.clearAllMemberLocations(widget.taskId);
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': 'resolved',
    });
  }

  // NEW — leader-only escape hatch for when a member can't self-update
  // (phone unreachable, etc). Unlike the member's sequential buttons, this
  // is a pick-any-option dialog, since overriding deliberately breaks the
  // normal assigned -> enroute -> in_progress -> resolved sequence instead
  // of advancing through it.
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

  Future<void> _forceUpdateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': newStatus,
      // Kept separate from the member's own status updates so it's always
      // clear — to the member and to admin — that this particular change
      // came from the leader overriding the flow.
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

          // NEW — makes the override feature actually take effect: if this
          // device was tracking this task and the status just moved away
          // from 'enroute' (whether the member or the leader changed it),
          // stop the GPS stream instead of leaving it running.
          EnrouteTrackingService.instance.stopIfTaskNoLongerEnroute(widget.taskId, status);

          _loadTaskTypeIcon(taskType);

          final double lat = (taskData['latitude'] ?? 31.5204).toDouble();
          final double lng = (taskData['longitude'] ?? 74.3587).toDouble();

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

                _buildMemberList(taskData),

                const SizedBox(height: 12),

                _buildLiveStatusCard(status, taskData),

                const SizedBox(height: 20),

                _buildActionButtons(status, taskData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTrackingMap(Map<String, dynamic> taskData, String taskType, double lat, double lng) {
    final Map<String, dynamic> memberLocations = Map<String, dynamic>.from(taskData['memberLocations'] ?? {});
    final Set<Marker> markers = {};

    // 1. Task/Incident Location Marker
    markers.add(
      Marker(
        markerId: const MarkerId('incident_location'),
        position: LatLng(lat, lng),
        icon: markerIconCache[taskType] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Emergency: $taskType',
          snippet: taskData['address'] ?? 'Incident Location',
        ),
      ),
    );

    // 2. Dynamic Team Members Live Location Markers
    memberLocations.forEach((uid, locData) {
      if (locData is Map && locData.containsKey('lat') && locData.containsKey('lng')) {
        final double memberLat = (locData['lat'] as num).toDouble();
        final double memberLng = (locData['lng'] as num).toDouble();

        markers.add(
          Marker(
            markerId: MarkerId('member_$uid'),
            position: LatLng(memberLat, memberLng),
            icon: markerIconCache['member'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(
              title: 'Team Member',
              snippet: 'Enroute / On Location',
            ),
          ),
        );
      }
    });

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 13),
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }

  Widget _buildMemberList(Map<String, dynamic> taskData) {
    final List assignedMembers = taskData['assignedMembers'] ?? [];
    if (assignedMembers.isEmpty) {
      return const Text('No team members assigned yet.', style: TextStyle(color: Colors.black45));
    }

    return Column(
      children: assignedMembers.map((m) {
        final name = m is Map ? (m['name'] ?? 'Member') : m.toString();
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
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveStatusCard(String status, Map<String, dynamic> taskData) {
    String message = '';
    Color cardColor = Colors.white;
    Color textColor = Colors.black87;

    switch (status) {
      case 'enroute':
        message = 'Assigned member is enroute to the location';
        cardColor = Colors.white;
        textColor = Colors.black54;
        break;
      case 'in_progress':
        message = 'Team member has arrived and task is in progress';
        cardColor = Colors.blue.shade50;
        textColor = Colors.blue.shade900;
        break;
      case 'resolved':
      case 'completed':
        message = 'Task completed successfully by assigned team';
        cardColor = Colors.green.shade50;
        textColor = kGreen;
        break;
      default:
        return const SizedBox.shrink();
    }

    // NEW — surfaces that this particular change came from the leader's
    // emergency override rather than the member's own action.
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

  Widget _buildActionButtons(String status, Map<String, dynamic> taskData) {
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
            // NEW — only once a member is actually assigned does an override
            // make sense (there's nothing to override before that).
            if (status == 'assigned') ...[
              const SizedBox(height: 8),
              _overrideButton(status),
            ],
          ],
        );
      }
      // NEW — previously nothing showed here for the leader once the task
      // moved past "assigned"; now the emergency override is reachable for
      // as long as the task is still active.
      if (status == 'enroute' || status == 'in_progress') {
        return _overrideButton(status);
      }
    } else {
      final List assignedMemberIds = taskData['assignedMemberIds'] ?? [];
      if (assignedMemberIds.contains(_uid)) {
        if (status == 'assigned') {
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
        if (status == 'enroute') {
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
        if (status == 'in_progress') {
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
      }
    }

    return const SizedBox.shrink();
  }
}