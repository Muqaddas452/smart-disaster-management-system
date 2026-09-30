import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smartdisaster/database/map_icon_helper.dart';
import 'enroute_tracking_service.dart';
import 'assign_members_screen.dart';

class ViewTaskScreen extends StatefulWidget {
  final String taskId;

  const ViewTaskScreen({super.key, required this.taskId});

  @override
  State<ViewTaskScreen> createState() => _ViewTaskScreenState();
}

class _ViewTaskScreenState extends State<ViewTaskScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  // Task ka red pin map pe dikhana hai ya nahi (member ke liye zaroori hai).
  // Agar leader ke map pe sirf members chahiye to isay false kar dein.
  static const bool _showTaskMarker = true;

  String? _uid;
  String? _teamId;
  bool _isLeader = false;
  bool _iconsLoaded = false;

  BitmapDescriptor? _memberIcon;
  GoogleMapController? _mapController;
  int _lastFitCount = -1;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _precacheMapIcons();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
        _teamId = data['teamId'];
      });
    }
  }

  // Member ka icon sirf EK baar banta hai (pehle har rebuild pe banta tha).
  // Agar custom icon fail ho jaye to default blue marker use hoga,
  // taake markers kabhi silently gayab na hon.
  Future<void> _precacheMapIcons() async {
    try {
      _memberIcon = await createDirectIconMarker(Icons.person, Colors.blue.shade700, size: 50);
    } catch (e) {
      debugPrint('ViewTask: member icon failed - $e');
      _memberIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    if (mounted) setState(() => _iconsLoaded = true);
  }

  // --- TASK STATUS ACTIONS ---
  Future<void> _acceptTask() async {
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'status': 'accepted',
    });
  }

  // FIXED: pehle status 'enroute' set hota hai, phir tracking start hoti hai.
  // Pehle ulta tha, is liye pehli location likhte hi build() mein
  // stopIfTaskNoLongerEnroute tracking ko galat stop kar deta tha.
  // Ab agar tracking start na ho (permission deny etc.) to status wapis
  // 'assigned' ho jata hai aur member ko message milta hai.
  Future<void> _markEnroute() async {
    if (_uid == null) return;
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);

    await taskRef.update({'memberStatuses.$_uid': 'enroute'});
    final started = await EnrouteTrackingService.instance.startTracking(widget.taskId);

    if (!started) {
      await taskRef.update({'memberStatuses.$_uid': 'assigned'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission/GPS required. Please allow location and turn on GPS.'),
          ),
        );
      }
    }
  }

  Future<void> _startTask() async {
    await EnrouteTrackingService.instance.stopTracking();
    await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
      'memberStatuses.$_uid': 'in_progress',
    });
  }

  Future<void> _markCompleted() async {
    await EnrouteTrackingService.instance.stopTracking();
    if (_uid != null) {
      await EnrouteTrackingService.clearMemberLocation(widget.taskId, _uid!);
    }

    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
    await taskRef.update({'memberStatuses.$_uid': 'completed'});

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

  // --- STATUS HELPERS (member list aur map dono use karte hain) ---
  String _labelFor(String? statusValue) {
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

  Color _colorFor(String? statusValue) {
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
          final String status = taskData['status'] ?? 'dispatched';
          final Map<String, dynamic> memberStatuses =
          Map<String, dynamic>.from(taskData['memberStatuses'] ?? {});

          final String myStatus = (_uid != null ? memberStatuses[_uid] : null) ?? 'assigned';
          EnrouteTrackingService.instance.stopIfTaskNoLongerEnroute(widget.taskId, myStatus);

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
                Text(
                  _isLeader ? 'LIVE TRACKING (TEAM MEMBERS)' : 'LIVE TRACKING (YOU & TASK)',
                  style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Container(
                  height: 220,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: _buildLiveTrackingMap(taskData, memberStatuses, lat, lng),
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

  // CHANGED: FutureBuilder hata diya. Markers ab seedha (synchronously)
  // bante hain kyunke icon pehle se cached hai. Camera bhi markers ke
  // hisaab se khud fit hota hai.
  Widget _buildLiveTrackingMap(
      Map<String, dynamic> taskData,
      Map<String, dynamic> memberStatuses,
      double lat,
      double lng,
      ) {
    final markers = _buildMarkers(taskData, memberStatuses, lat, lng);
    final points = markers.map((m) => m.position).toList();

    // Camera sirf tab dobara fit hota hai jab markers ki tadaad badle
    // (taake user map ko pan kare to camera wapis na kheenche).
    if (points.length != _lastFitCount) {
      _lastFitCount = points.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(points));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 13),
      markers: markers,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCamera(points);
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }

  Future<void> _fitCamera(List<LatLng> points) async {
    final c = _mapController;
    if (c == null || points.isEmpty) return;

    try {
      double minLat = points.first.latitude, maxLat = points.first.latitude;
      double minLng = points.first.longitude, maxLng = points.first.longitude;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      if (minLat == maxLat && minLng == maxLng) {
        await c.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
        return;
      }

      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          60,
        ),
      );
    } catch (e) {
      debugPrint('ViewTask: camera fit failed - $e');
    }
  }

  // ROLE-BASED markers:
  //  - Leader: apni team ke SAB assigned members (+ task pin)
  //  - Member: sirf APNA marker (+ task pin)
  Set<Marker> _buildMarkers(
      Map<String, dynamic> taskData,
      Map<String, dynamic> memberStatuses,
      double lat,
      double lng,
      ) {
    final Set<Marker> markers = {};
    final Map<String, dynamic> memberLocations =
    Map<String, dynamic>.from(taskData['memberLocations'] ?? {});
    final List assignedMembers = taskData['assignedMembers'] ?? [];
    final List assignedIds = taskData['assignedMemberIds'] ?? [];

    if (_showTaskMarker) {
      markers.add(
        Marker(
          markerId: const MarkerId('task_location'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Task Location'),
        ),
      );
    }

    // Kaun kaun se uids ka marker dikhana hai
    final List<String> visibleUids = _isLeader
        ? assignedIds.map((e) => e.toString()).toList()
        : (_uid != null ? [_uid!] : <String>[]);

    for (final uid in visibleUids) {
      final locData = memberLocations[uid];
      if (locData is! Map || locData['lat'] == null || locData['lng'] == null) continue;

      final double memberLat = (locData['lat'] as num).toDouble();
      final double memberLng = (locData['lng'] as num).toDouble();

      String memberName = uid == _uid ? 'You' : 'Team Member';
      if (uid != _uid) {
        for (final m in assignedMembers) {
          if (m is Map && (m['uid'] == uid || m['id'] == uid)) {
            memberName = (m['name'] ?? 'Team Member').toString();
            break;
          }
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId('member_$uid'),
          position: LatLng(memberLat, memberLng),
          icon: _memberIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: memberName,
            snippet: _labelFor(memberStatuses[uid] as String?),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMemberList(Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    final List assignedMembers = taskData['assignedMembers'] ?? [];
    if (assignedMembers.isEmpty) {
      return const Text('No team members assigned yet.', style: TextStyle(color: Colors.black45));
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
                    color: _colorFor(memberStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labelFor(memberStatus),
                    style: TextStyle(color: _colorFor(memberStatus), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

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