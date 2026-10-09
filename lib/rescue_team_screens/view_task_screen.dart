import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smartdisaster/database/map_icon_helper.dart';
import 'package:smartdisaster/utils/priority_helper.dart';
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

  // Alert/task ki location par red pin (live map par destination).
  static const bool _showTaskMarker = true;

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posSub; // member ki apni live location (map ke liye)
  LatLng? _myPos;
  Map<String, String>? _prevStatuses; // leader ko status change ka alert dene ke liye
  int _lastFitCount = -1;
  bool _busy = false; // double-tap se bachne ke liye
  bool _resumingTracking = false;
  bool _resumeFailed = false;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _posSub?.cancel();
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
        _teamId = data['teamId']; // Fetch teamId from Firestore doc
      });
      if (!_isLeader) _startOwnLocation();
    }
  }

  // Member ko map par APNI location (aur task tak raasta) dikhane ke liye.
  // Yeh tracking (Firestore mein location likhna) se alag hai — sirf is screen
  // ke liye local hai, jab tak screen khuli hai.
  Future<void> _startOwnLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final first = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _myPos = LatLng(first.latitude, first.longitude));

      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((p) {
        if (mounted) setState(() => _myPos = LatLng(p.latitude, p.longitude));
      });
    } catch (e) {
      debugPrint('ViewTask: own location failed - $e');
    }
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final String origin =
    _myPos != null ? '&origin=${_myPos!.latitude},${_myPos!.longitude}' : '';
    final Uri uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1$origin&destination=$lat,$lng&travelmode=driving');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('Could not open Google Maps.');
    } catch (e) {
      _snack('Could not open Google Maps.');
    }
  }

  // Leader ko foran pata chale jab koi member ka status badle
  // (jaise "Ali is now Enroute").
  void _notifyStatusChanges(Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    final Map<String, String> current =
    memberStatuses.map((k, v) => MapEntry(k, v.toString()));
    final prev = _prevStatuses;
    _prevStatuses = current;
    if (prev == null) return; // pehli dafa load — alert nahi

    final List assigned = taskData['assignedMembers'] ?? [];
    for (final e in current.entries) {
      if (prev[e.key] == e.value) continue;
      String name = 'Member';
      for (final m in assigned) {
        if (m is Map && (m['uid'] ?? m['id']) == e.key) {
          name = (m['name'] ?? 'Member').toString();
          break;
        }
      }
      final msg = '$name is now ${_labelFor(e.value)}';
      WidgetsBinding.instance.addPostFrameCallback((_) => _snack(msg));
    }
  }

  // --- TASK STATUS ACTIONS ---
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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

  Future<void> _acceptTask() async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
        'status': 'accepted',
        'acceptedBy': _uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _snack('Could not accept task: $e');
    }
  }

  // Leader ke paas task reject karne ka koi raasta nahi tha (status list mein
  // 'rejected' maujood tha lekin kahin set nahi hota tha).
  Future<void> _rejectTask() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject task?'),
        content: const Text('This task will be closed as rejected for your team.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
        'status': 'rejected',
        'rejectedBy': _uid,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _snack('Could not reject task: $e');
    }
  }

  // Per-member status: har member ka apna `memberStatuses.{uid}`.
  //
  // FIXED: pehle tracking start hoti thi aur status baad mein likha jata tha.
  // Is se (1) pehli location likhte hi build() ka safety-net tracking ko
  // galat stop kar deta tha, aur (2) permission/GPS na milne par bhi status
  // 'enroute' ho jata tha. Ab pehle status, phir tracking; tracking start na
  // ho to status wapis 'assigned' aur member ko message.
  Future<void> _markEnroute() async {
    if (_uid == null || _busy) return;
    setState(() => _busy = true);
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
    try {
      await taskRef.update({'memberStatuses.$_uid': 'enroute'});
      final started = await EnrouteTrackingService.instance.startTracking(widget.taskId);
      if (!started) {
        await taskRef.update({'memberStatuses.$_uid': 'assigned'});
        _snack('Location permission/GPS required. Please allow location and turn on GPS.');
      }
    } catch (e) {
      _snack('Could not update status: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTask() async {
    if (_uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      // Member pohanch gaya — sirf APNI tracking band hoti hai.
      await EnrouteTrackingService.instance.stopTracking();
      await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
        'memberStatuses.$_uid': 'in_progress',
      });
    } catch (e) {
      _snack('Could not update status: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Transaction: do members ek saath "completed" dabayen to dono ek doosre
  // ka update nahi dekhte the aur task kabhi 'resolved' nahi hota tha.
  // Ab status + "sab complete?" check ek hi transaction mein hota hai.
  Future<bool> _setMemberStatus(String memberUid, String newStatus, {bool override = false}) {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(taskRef);
      final data = snap.data() ?? {};
      final List assignedIds = List.from(data['assignedMemberIds'] ?? []);
      final Map<String, dynamic> statuses =
      Map<String, dynamic>.from(data['memberStatuses'] ?? {});
      statuses[memberUid] = newStatus;

      final bool allDone =
          assignedIds.isNotEmpty && assignedIds.every((id) => statuses[id] == 'completed');

      final Map<String, dynamic> updates = {'memberStatuses.$memberUid': newStatus};
      if (allDone) {
        updates['status'] = 'resolved';
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }
      if (override) {
        updates['statusOverriddenBy'] = _uid;
        updates['statusOverriddenAt'] = FieldValue.serverTimestamp();
      }
      tx.update(taskRef, updates);
      return allDone;
    });
  }

  Future<void> _markCompleted() async {
    if (_uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      await EnrouteTrackingService.instance.stopTracking();
      await EnrouteTrackingService.clearMemberLocation(widget.taskId, _uid!);
      final bool allDone = await _setMemberStatus(_uid!, 'completed');
      if (allDone) {
        await EnrouteTrackingService.clearAllMemberLocations(widget.taskId);
      }
    } catch (e) {
      _snack('Could not complete task: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // App band/dobara khulne par member Firestore mein 'enroute' hota hai lekin
  // tracking process mar chuki hoti hai — location updates band. Yeh tracking
  // dobara shuru karta hai (sirf ek dafa try karta hai).
  Future<void> _resumeTracking() async {
    _resumingTracking = true;
    try {
      final ok = await EnrouteTrackingService.instance.startTracking(widget.taskId);
      if (!ok) {
        _resumeFailed = true;
        _snack('Location sharing is off. Allow location and turn on GPS so your team can see you.');
      }
    } finally {
      _resumingTracking = false;
    }
  }

  // Leader override ab PER MEMBER hai (pehle task-level status badalta tha,
  // jis se saare members ke buttons gayab ho jate the aur leader bhi lock ho
  // jata tha).
  Future<void> _showOverrideDialog(
      Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) async {
    final List assignedMembers = taskData['assignedMembers'] ?? [];

    final String? picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override status'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Use this only if a member cannot update their own status (e.g. unreachable). Pick the member:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              ...assignedMembers.whereType<Map>().map<Widget>((m) {
                final String? memberUid = (m['uid'] ?? m['id'])?.toString();
                if (memberUid == null) return const SizedBox.shrink();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((m['name'] ?? 'Member').toString()),
                  subtitle: Text(_labelFor(memberStatuses[memberUid] as String?)),
                  onTap: () => Navigator.pop(ctx, memberUid),
                );
              }),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.done_all, color: kGreen),
                title: const Text('Resolve entire task'),
                onTap: () => Navigator.pop(ctx, '__resolve_all__'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    if (picked == '__resolve_all__') {
      await _forceResolveTask();
      return;
    }

    const labels = {
      'assigned': 'Assigned (reset)',
      'enroute': 'Enroute',
      'in_progress': 'In Progress',
      'completed': 'Completed',
    };
    final String? current = memberStatuses[picked] as String?;
    final String? newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set member status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: labels.keys
              .where((k) => k != (current ?? 'assigned'))
              .map((k) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(labels[k]!),
            onTap: () => Navigator.pop(ctx, k),
          ))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (newStatus == null) return;

    try {
      final bool allDone = await _setMemberStatus(picked, newStatus, override: true);
      if (newStatus == 'completed' || newStatus == 'assigned') {
        await EnrouteTrackingService.clearMemberLocation(widget.taskId, picked);
      }
      if (allDone) await EnrouteTrackingService.clearAllMemberLocations(widget.taskId);
    } catch (e) {
      _snack('Override failed: $e');
    }
  }

  Future<void> _forceResolveTask() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve entire task?'),
        content: const Text('This closes the task for all assigned members.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'statusOverriddenBy': _uid,
        'statusOverriddenAt': FieldValue.serverTimestamp(),
      });
      await EnrouteTrackingService.clearAllMemberLocations(widget.taskId);
    } catch (e) {
      _snack('Could not resolve task: $e');
    }
  }

  Widget _overrideButton(Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => _showOverrideDialog(taskData, memberStatuses),
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
          final String status = taskData['status'] ?? 'dispatched';
          final Map<String, dynamic> memberStatuses =
          Map<String, dynamic>.from(taskData['memberStatuses'] ?? {});

          if (_isLeader) _notifyStatusChanges(taskData, memberStatuses);

          // Safety net: tracking sirf tab chalni chahiye jab (a) yeh member is
          // task par assigned ho, (b) task abhi 'assigned' (active) ho, aur
          // (c) iska apna status 'enroute' ho. Warna (resolved/rejected/member
          // hata diya gaya/leader ne override kiya) to tracking band.
          final List assignedIds = List.from(taskData['assignedMemberIds'] ?? []);
          final bool amAssigned = _uid != null && assignedIds.contains(_uid);
          final String myStatus = (_uid != null ? memberStatuses[_uid] : null) ?? 'assigned';
          final bool trackingAllowed = amAssigned && status == 'assigned' && myStatus == 'enroute';
          EnrouteTrackingService.instance
              .stopIfTaskNoLongerEnroute(widget.taskId, trackingAllowed ? 'enroute' : 'stopped');

          // App dobara khuli aur member 'enroute' hai magar tracking nahi chal
          // rahi => resume.
          if (trackingAllowed &&
              !_resumingTracking &&
              !_resumeFailed &&
              !EnrouteTrackingService.instance.isTracking) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_resumingTracking) _resumeTracking();
            });
          }

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
                        Builder(builder: (_) {
                          // List screen jaisi hi priority aur rang (shared helper).
                          final String pr = resolvePriority(taskData);
                          final pc = priorityColors(pr);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: pc[0],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${priorityLabel(pr)} priority',
                              style: TextStyle(color: pc[1], fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text(
                          'Emergency: ${taskType(taskData, fallback: 'Alert')}',
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
                                    Text(taskAddress(taskData, fallback: 'Address Unavailable'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                Text(_isLeader ? 'LIVE TRACKING (TEAM MEMBERS)' : 'LIVE TRACKING (YOU & TASK)', style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Container(
                  height: 220,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                  child: _buildLiveTrackingMap(taskData, memberStatuses, lat, lng),
                ),

                if (!_isLeader) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.directions, color: kGreen),
                      label: const Text('Navigate to task location',
                          style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
                      onPressed: () => _openNavigation(lat, lng),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Text(_isLeader ? 'ASSIGNED TEAM MEMBERS' : 'YOUR STATUS', style: TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold)),
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

  // Kaun kaun si positions map par dikhani hain:
  //  - Leader: apni team ke SAB assigned members (jin ki location Firestore mein hai)
  //  - Member: sirf APNI (local live GPS, warna Firestore wali)
  Map<String, LatLng> _visiblePositions(Map<String, dynamic> taskData) {
    final Map<String, dynamic> memberLocations =
    Map<String, dynamic>.from(taskData['memberLocations'] ?? {});
    final List assignedIds = taskData['assignedMemberIds'] ?? [];
    final Map<String, LatLng> out = {};

    LatLng? fromDoc(String uid) {
      final loc = memberLocations[uid];
      if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
        return LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());
      }
      return null;
    }

    if (_isLeader) {
      for (final id in assignedIds) {
        final p = fromDoc(id.toString());
        if (p != null) out[id.toString()] = p;
      }
    } else if (_uid != null) {
      final p = _myPos ?? fromDoc(_uid!);
      if (p != null) out[_uid!] = p;
    }
    return out;
  }

  Widget _buildLiveTrackingMap(
      Map<String, dynamic> taskData,
      Map<String, dynamic> memberStatuses,
      double lat,
      double lng,
      ) {
    final taskPoint = LatLng(lat, lng);
    final positions = _visiblePositions(taskData);
    final markers = _buildMarkers(taskData, memberStatuses, positions, lat, lng);

    // Member/leader se task tak dashed line (seedhi lakeer, road route nahi).
    final Set<Polyline> polylines = {};
    positions.forEach((uid, pos) {
      polylines.add(Polyline(
        polylineId: PolylineId('route_$uid'),
        points: [pos, taskPoint],
        color: Colors.blue.shade700,
        width: 3,
        patterns: [PatternItem.dash(18), PatternItem.gap(10)],
      ));
    });

    final points = <LatLng>[taskPoint, ...positions.values];

    // Camera sirf tab dobara fit hota hai jab points ki tadaad badle
    // (taake user pan kare to wapis na kheenche).
    if (points.length != _lastFitCount) {
      _lastFitCount = points.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(points));
    }

    // Member ke liye: task se kitna door hai.
    String? distanceText;
    if (!_isLeader && _uid != null && positions[_uid] != null) {
      final meters = Geolocator.distanceBetween(
          positions[_uid]!.latitude, positions[_uid]!.longitude, lat, lng);
      distanceText = meters >= 1000
          ? '${(meters / 1000).toStringAsFixed(1)} km to task'
          : '${meters.round()} m to task';
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: taskPoint, zoom: 13),
          markers: markers,
          polylines: polylines,
          // Map scrollable page ke andar hai — iske baghair map ko ungli se
          // hilane par poora page scroll hota tha, map pan nahi hota tha.
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onMapCreated: (controller) {
            _mapController = controller;
            _fitCamera(points);
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        if (distanceText != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
              ),
              child: Text(distanceText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGreen)),
            ),
          ),
      ],
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
          LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
          70,
        ),
      );
    } catch (e) {
      debugPrint('ViewTask: camera fit failed - $e');
    }
  }

  double _hueForStatus(String? st) {
    switch (st) {
      case 'enroute':
        return BitmapDescriptor.hueOrange;
      case 'in_progress':
        return BitmapDescriptor.hueAzure;
      case 'completed':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  Set<Marker> _buildMarkers(
      Map<String, dynamic> taskData,
      Map<String, dynamic> memberStatuses,
      Map<String, LatLng> positions,
      double lat,
      double lng,
      ) {
    final Set<Marker> markers = {};
    final List assignedMembers = taskData['assignedMembers'] ?? [];

    // Alert / task ki location
    if (_showTaskMarker) {
      markers.add(Marker(
        markerId: const MarkerId('task_location'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Alert: ${taskType(taskData)}',
          snippet: taskAddress(taskData, fallback: ''),
        ),
      ));
    }

    // Members: "Naam · Status" wale label marker (live update hote hain)
    positions.forEach((uid, pos) {
      final String? st = memberStatuses[uid] as String?;
      final String statusLabel = _labelFor(st);

      String name = uid == _uid ? 'You' : 'Member';
      if (uid != _uid) {
        for (final m in assignedMembers) {
          if (m is Map && (m['uid'] == uid || m['id'] == uid)) {
            name = (m['name'] ?? 'Member').toString();
            break;
          }
        }
      }

      final String text = '$name · $statusLabel';
      final String key = 'task_$text';
      final BitmapDescriptor? labelIcon = LabelMarkerCache.lookup(key);
      if (labelIcon == null) {
        LabelMarkerCache.prepare(key, text, _colorFor(st), () {
          if (mounted) setState(() {});
        });
      }

      markers.add(Marker(
        markerId: MarkerId('member_$uid'),
        position: pos,
        // label tayar hone tak rang wala default marker
        icon: labelIcon ?? BitmapDescriptor.defaultMarkerWithHue(_hueForStatus(st)),
        infoWindow: InfoWindow(title: name, snippet: statusLabel),
      ));
    });

    return markers;
  }

  // CHANGED: now also shows each member's individual status (from
  // `memberStatuses`) next to their name, instead of just a plain name
  // list — this is the "leader can see each member's status
  // individually" part of the fix.
  Widget _buildMemberList(Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    List assignedMembers = taskData['assignedMembers'] ?? [];

    // PRIVACY: member ko sirf APNA naam/status dikhta hai, doosre assigned
    // members ka nahi. (Leader ko sab ka.)
    if (!_isLeader) {
      assignedMembers = assignedMembers
          .where((m) => m is Map && (m['uid'] ?? m['id']) == _uid)
          .toList();
    }

    if (assignedMembers.isEmpty) {
      return Text(
        _isLeader ? 'No team members assigned yet.' : 'You are not assigned to this task.',
        style: const TextStyle(color: Colors.black45),
      );
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

  // CHANGED: once the task has been assigned to members, this now shows
  // an aggregate summary built from `memberStatuses` (e.g. "1 of 3
  // members completed") instead of one generic sentence that implied a
  // single assigned member.
  Widget _buildLiveStatusCard(
      String status, Map<String, dynamic> taskData, Map<String, dynamic> memberStatuses) {
    String message = '';
    Color cardColor = Colors.white;
    Color textColor = Colors.black87;

    if (status == 'assigned' && !_isLeader) {
      // Member ko team ka hisaab (jaise "1 of 3 completed") nahi dikhta —
      // sirf apni halat.
      final String mine = (_uid != null ? memberStatuses[_uid] : null) as String? ?? 'assigned';
      switch (mine) {
        case 'enroute':
          message = 'You are on your way to the task location';
          cardColor = Colors.orange.shade50;
          textColor = Colors.orange.shade900;
          break;
        case 'in_progress':
          message = 'You are working on this task';
          cardColor = Colors.blue.shade50;
          textColor = Colors.blue.shade900;
          break;
        case 'completed':
          message = "You've completed your part of this task";
          cardColor = Colors.green.shade50;
          textColor = kGreen;
          break;
        default:
          message = 'Waiting for you to start';
          textColor = Colors.black54;
      }
    } else if (status == 'assigned') {
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
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _acceptTask,
                child: const Text('Accept Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _rejectTask,
                child: Text('Reject Task', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
              _overrideButton(taskData, memberStatuses),
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
              onPressed: _busy ? null : _markEnroute,
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
              onPressed: _busy ? null : _startTask,
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
              onPressed: _busy ? null : _markCompleted,
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