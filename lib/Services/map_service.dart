import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/polygon_model.dart';
import '../models/rescue_team_model.dart';

class MapService {
  MapService._();

  static final MapService instance = MapService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //----------------------------------------------------------
  // Live Affected Zones
  //
  // IMPORTANT: real `affected_zones` documents only store a
  // single `latitude`/`longitude` point plus `disasterType` and
  // `riskLevel` — there is no `coordinates` boundary array.
  // Feeding that straight into PolygonModel.fromFirestore()
  // produces an EMPTY coordinates list, which Google Maps
  // rejects with "List<LatLng> cannot be empty." — this was the
  // exact crash seen in the console.
  //
  // Fix: same buffer-circle approach as tasks — build a circle
  // around the zone's point, sized by riskLevel.
  //----------------------------------------------------------

  Stream<List<PolygonModel>> getAffectedZones() {
    return _firestore.collection("affected_zones").snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) =>
      doc.data()['latitude'] != null &&
          doc.data()['longitude'] != null &&
          (doc.data()['status'] ?? '').toString().toLowerCase() !=
              'resolved')
          .map((doc) => _zoneDocToPolygon(doc))
          .toList();
    });
  }

  //----------------------------------------------------------
  // Zone Document -> PolygonModel (buffer-circle generation)
  //----------------------------------------------------------

  PolygonModel _zoneDocToPolygon(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final double lat = (data['latitude'] as num).toDouble();
    final double lng = (data['longitude'] as num).toDouble();
    final String riskLevel = (data['riskLevel'] ?? 'Medium').toString();
    final String disasterType = (data['disasterType'] ?? 'Unknown').toString();

    return PolygonModel(
      id: doc.id,
      type: disasterType,
      severity: riskLevel,
      color: _colorForLevel(riskLevel),
      coordinates: _generateCirclePolygon(
        centerLat: lat,
        centerLng: lng,
        radiusKm: _radiusForZoneRisk(riskLevel),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  //----------------------------------------------------------
  // Latest Active Alert (Rescue Home Screen top card + mini map)
  //
  // broadcast_alerts fields: city, createdAt, disaster,
  // latitude, longitude, message, riskLevel, sourceAlertId,
  // status, title.
  //----------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> getLatestActiveAlertDoc() {
    return _firestore
        .collection('broadcast_alerts')
        .where('status', isEqualTo: 'Active')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  /// Converts one broadcast_alerts document into a PolygonModel
  /// (buffer-circle, same technique as zones/tasks) so the Home
  /// screen's mini map can show that single alert's area without
  /// a second Firestore listener.
  PolygonModel alertDataToPolygon(Map<String, dynamic> data, String id) {
    final double lat = (data['latitude'] as num).toDouble();
    final double lng = (data['longitude'] as num).toDouble();
    final String riskLevel = (data['riskLevel'] ?? 'Medium').toString();
    final String disasterType = (data['disaster'] ?? 'Unknown').toString();

    return PolygonModel(
      id: id,
      type: disasterType,
      severity: riskLevel,
      color: _colorForLevel(riskLevel),
      coordinates: _generateCirclePolygon(
        centerLat: lat,
        centerLng: lng,
        radiusKm: _radiusForZoneRisk(riskLevel),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  //----------------------------------------------------------
  // Rescue Teams
  //----------------------------------------------------------

  Stream<List<RescueTeamModel>> getRescueTeams() {
    return Stream.value([]);
  }

  //----------------------------------------------------------
  // Live Task Zones (Rescue Team app — "Tasks" map tab)
  //
  // Builds a PolygonModel per active task by drawing a buffer
  // circle around the task's lat/lng. Leaders see every task
  // for their team; members see only tasks assigned to them.
  //
  // Once a task's status leaves the "active on map" list below
  // (i.e. it becomes resolved), this Firestore query stops
  // returning it, so the polygon disappears from the map by
  // itself — no manual "remove polygon" code needed anywhere.
  //----------------------------------------------------------

  static const List<String> _activeTaskStatuses = [
    'accepted',
    'assigned',
    'in_progress',
  ];

  Stream<List<PolygonModel>> getTaskZones({
    required bool isLeader,
    required String idValue,
  }) {
    final Query<Map<String, dynamic>> query = isLeader
        ? _firestore
        .collection('tasks')
        .where('teamId', isEqualTo: idValue)
        .where('status', whereIn: _activeTaskStatuses)
        : _firestore
        .collection('tasks')
        .where('assignedMemberIds', arrayContains: idValue)
        .where('status', whereIn: _activeTaskStatuses);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) =>
      doc.data()['lat'] != null && doc.data()['lng'] != null)
          .map((doc) => _taskDocToPolygon(doc))
          .toList();
    });
  }

  //----------------------------------------------------------
  // Task Document -> PolygonModel (buffer-circle generation)
  //
  // Tasks only store a single lat/lng, not a boundary, so we
  // approximate an affected radius around that point, sized by
  // priority. This reuses the exact same PolygonModel shape
  // that PolygonLayer already knows how to render.
  //----------------------------------------------------------

  PolygonModel _taskDocToPolygon(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    final double lat = (data['lat'] as num).toDouble();
    final double lng = (data['lng'] as num).toDouble();
    final String priority = (data['priority'] ?? 'medium').toString();
    final String type = (data['type'] ?? 'Task').toString();

    return PolygonModel(
      id: doc.id,
      type: type,
      severity: priority,
      color: _colorForLevel(priority),
      coordinates: _generateCirclePolygon(
        centerLat: lat,
        centerLng: lng,
        radiusKm: _radiusForTaskPriority(priority),
      ),
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  //----------------------------------------------------------
  // Buffer Circle Generator
  //
  // Approximates a circular polygon around a center point.
  // Shared by both zones (regional radius) and tasks (pinpoint
  // radius) since neither has real boundary data.
  //----------------------------------------------------------

  List<LatLng> _generateCirclePolygon({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    int points = 24,
  }) {
    const double earthRadiusKm = 6371.0;
    final List<LatLng> coordinates = [];

    for (int i = 0; i < points; i++) {
      final double angle = (2 * pi * i) / points;

      final double dLat = (radiusKm / earthRadiusKm) * cos(angle);
      final double dLng =
          (radiusKm / earthRadiusKm) * sin(angle) / cos(centerLat * pi / 180);

      final double pointLat = centerLat + (dLat * 180 / pi);
      final double pointLng = centerLng + (dLng * 180 / pi);

      coordinates.add(LatLng(pointLat, pointLng));
    }

    return coordinates;
  }

  //----------------------------------------------------------
  // Radius scaling — zones are regional (bigger), tasks are
  // pinpoint (smaller). Both use the same high/medium/low words.
  //----------------------------------------------------------

  double _radiusForZoneRisk(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return 15.0;
      case 'medium':
        return 8.0;
      case 'low':
        return 4.0;
      default:
        return 8.0;
    }
  }

  double _radiusForTaskPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3.0;
      case 'medium':
        return 1.5;
      case 'low':
        return 0.8;
      default:
        return 1.5;
    }
  }

  //----------------------------------------------------------
  // Color mapping — shared by zones (riskLevel) and tasks
  // (priority), since both use the same high/medium/low words.
  //----------------------------------------------------------

  String _colorForLevel(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return 'red';
      case 'medium':
        return 'orange';
      case 'low':
        return 'yellow';
      default:
        return 'orange';
    }
  }
}