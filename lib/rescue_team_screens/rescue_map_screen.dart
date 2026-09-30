import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:smartdisaster/widgets/map/disaster_map.dart';

/// Rescue Team Map Screen.
///
/// Shown under the bottom navigation bar's "Map" tab for BOTH
/// the leader and members — same screen, same widget. Two tabs:
///
/// 1. Affected Zones — reuses the same `affected_zones` data
///    that the Citizen app shows (no rescue-specific query needed).
/// 2. Tasks — one marker per active task, scoped to the whole team
///    (leader) or just the tasks assigned to this member. The camera
///    fits ALL of those markers, so a task in another city is still
///    visible without manually panning around.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("Not logged in."),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final bool isLeader = data['isLeader'] ?? false;
        final String teamId = data['teamId'] ?? '';

        // Leader's queries are scoped by teamId; a member's
        // queries are scoped by their own uid (assignedMemberIds).
        final String idValue = isLeader ? teamId : uid;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Map',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: Colors.green.shade800,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: "Affected Zones"),
                  Tab(text: "Tasks"),
                ],
              ),
            ),
            body: TabBarView(
              // Swiping between tabs would fight with map gestures.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Tab 1: Affected Zones (unchanged)
                DisasterMap(
                  isAdmin: false,
                  isRescueView: true,
                ),

                // Tab 2: Tasks — markers, not polygons
                _TasksMap(isLeader: isLeader, idValue: idValue),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tasks tab: one marker per active task, camera fitted to all of them.
// ─────────────────────────────────────────────────────────────
class _TasksMap extends StatefulWidget {
  final bool isLeader;
  final String idValue;

  const _TasksMap({required this.isLeader, required this.idValue});

  @override
  State<_TasksMap> createState() => _TasksMapState();
}

class _TasksMapState extends State<_TasksMap> {
  GoogleMapController? _controller;
  String _lastFittedKey = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    Query<Map<String, dynamic>> query =
    FirebaseFirestore.instance.collection('tasks');
    query = widget.isLeader
        ? query.where('teamId', isEqualTo: widget.idValue)
        : query.where('assignedMemberIds', arrayContains: widget.idValue);
    return query.snapshots();
  }

  double? _toDouble(dynamic v) => v is num ? v.toDouble() : null;

  double _hueFor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return BitmapDescriptor.hueRed;
      case 'low':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueOrange;
    }
  }

  Future<void> _fitTo(List<LatLng> points) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;

    try {
      if (points.length == 1) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 14));
        return;
      }

      double minLat = points.first.latitude, maxLat = points.first.latitude;
      double minLng = points.first.longitude, maxLng = points.first.longitude;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80,
        ),
      );
    } catch (_) {
      // newLatLngBounds can throw if the map hasn't been laid out yet.
      await controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Surfaces things like permission-denied instead of showing a
          // blank map with no explanation.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load tasks:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final Set<Marker> markers = {};
        final List<LatLng> points = [];
        int skippedNoLocation = 0;

        for (final doc in docs) {
          final data = doc.data();

          if ((data['status'] ?? '').toString() == 'resolved') continue;

          final double? lat = _toDouble(data['lat'] ?? data['latitude']);
          final double? lng = _toDouble(data['lng'] ?? data['longitude']);
          if (lat == null || lng == null) {
            skippedNoLocation++;
            continue;
          }

          final position = LatLng(lat, lng);
          points.add(position);

          final String type = (data['type'] ?? 'Task').toString();
          final String address = (data['address'] ?? '').toString();
          final String priority = (data['priority'] ?? 'medium').toString();
          final String status = (data['status'] ?? '').toString();

          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(priority)),
              infoWindow: InfoWindow(
                title: type,
                snippet: [
                  if (address.isNotEmpty) address,
                  '$priority priority',
                  if (status.isNotEmpty) status,
                ].join(' • '),
              ),
            ),
          );
        }

        // Re-fit only when the set of visible tasks actually changes, so the
        // camera doesn't jump back every time an unrelated field updates.
        final String key = (markers.map((m) => m.markerId.value).toList()..sort()).join(',');
        if (key != _lastFittedKey) {
          _lastFittedKey = key;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitTo(points));
        }

        String? banner;
        if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
          banner = 'Loading tasks...';
        } else if (markers.isEmpty && skippedNoLocation > 0) {
          banner = '$skippedNoLocation task(s) have no location saved';
        } else if (markers.isEmpty) {
          banner = 'No active tasks assigned';
        } else if (skippedNoLocation > 0) {
          banner = '${markers.length} task(s) shown · $skippedNoLocation without location';
        } else {
          banner = '${markers.length} active task(s)';
        }

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(30.3753, 69.3451), // centre of Pakistan
                zoom: 5,
              ),
              markers: markers,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: true,
              onMapCreated: (controller) {
                _controller = controller;
                Future.delayed(const Duration(milliseconds: 400), () => _fitTo(points));
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(banner, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}