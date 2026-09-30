import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/polygon_model.dart';

class MapService {
  MapService._();

  static final MapService instance = MapService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //----------------------------------------------------------
  // Live Affected Zones
  //----------------------------------------------------------

  // Get latest active alert document for rescue home screen banner/map
  Stream<QuerySnapshot<Map<String, dynamic>>?> getLatestActiveAlertDoc() {
    return _firestore
        .collection('affected_zones')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }
  Stream<List<PolygonModel>> getAffectedZones() {
    return _firestore
        .collection("affected_zones")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PolygonModel.fromFirestore(doc))
          .toList();
    });
  }
  // Convert alert data document to PolygonModel for map rendering
  PolygonModel alertDataToPolygon(Map<String, dynamic> data, String docId) {
    return PolygonModel.fromFirestoreData(data, docId);
  }

  //----------------------------------------------------------
  // Task Zones (for the Rescue app's Map screen "Tasks" tab)
  //
  // FIXED: was reading `data['lat']` / `data['lng']`, but task
  // documents actually store coordinates as `latitude` / `longitude`
  // (see ViewTaskScreen, which reads `taskData['latitude']` /
  // `taskData['longitude']`). Since no task doc ever had a `lat`/`lng`
  // field, `lat`/`lng` were always null here, so every task was
  // silently dropped and the Tasks tab map always rendered empty.
  //
  // ALSO ADDED: resolved tasks are now excluded, so a completed task's
  // buffer-circle doesn't linger on the map forever.
  //----------------------------------------------------------
  Stream<List<PolygonModel>> getTaskZones({required bool isLeader, required String idValue}) {
    Query<Map<String, dynamic>> query = _firestore.collection('tasks');
    if (isLeader) {
      query = query.where('teamId', isEqualTo: idValue);
    } else {
      query = query.where('assignedMemberIds', arrayContains: idValue);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        // Resolved tasks shouldn't keep showing a zone on the map.
        final String status = (data['status'] ?? '').toString();
        if (status == 'resolved') return null;

        // Agar task ke pas lat/lng hain toh unka buffer circle polygon bana lein
        // Accepts either naming style (latitude/longitude OR lat/lng), or a
        // GeoPoint stored under `location`, since it isn't certain which one
        // the admin side writes when it converts a report into a task.
        final GeoPoint? geo = data['location'] is GeoPoint ? data['location'] as GeoPoint : null;
        final double? lat = ((data['latitude'] ?? data['lat']) as num?)?.toDouble() ?? geo?.latitude;
        final double? lng = ((data['longitude'] ?? data['lng'] ?? data['lon']) as num?)?.toDouble() ?? geo?.longitude;
        if (lat == null || lng == null) {
          // ignore: avoid_print
          print('getTaskZones: task ${doc.id} skipped — no usable coordinates. Fields present: ${data.keys.toList()}');
        }
        if (lat != null && lng != null) {
          return PolygonModel(
            id: doc.id,
            type: data['type'] ?? 'Task Zone',
            severity: data['priority'] ?? 'medium',
            color: 'orange',
            coordinates: _createCircleCoordinates(lat, lng, 1000), // 1km radius circle
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }
        return null;
      }).whereType<PolygonModel>().toList();
    });
  }

// Helper method for circular coordinates
  List<LatLng> _createCircleCoordinates(double lat, double lng, double radiusInMeters) {
    // Circle points generator logic ya simple box coordinates
    return [
      LatLng(lat + 0.005, lng),
      LatLng(lat, lng + 0.005),
      LatLng(lat - 0.005, lng),
      LatLng(lat, lng - 0.005),
    ];
  }

}