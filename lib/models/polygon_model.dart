import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents one disaster zone polygon.
///
/// Used by:
/// - User App
/// - Admin Dashboard
/// - Google Maps
class PolygonModel {
  /// Firestore document IDq
  final String id;

  /// Disaster type
  ///
  /// Examples:
  /// Flood
  /// Earthquake
  /// Heatwave
  /// Storm
  final String type;

  /// Severity level
  ///
  /// Low
  /// Medium
  /// High
  final String severity;

  /// Polygon color stored in Firestore
  ///
  /// Examples:
  /// red
  /// green
  /// orange
  final String color;

  /// Polygon coordinates
  final List<LatLng> coordinates;

  /// Last updated time
  final DateTime createdAt;

  PolygonModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.color,
    required this.coordinates,
    required this.createdAt,
  });
  // Check if a point (citizen location) is inside this polygon
  bool containsLocation(LatLng point) {
    int intersectCount = 0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      if (_rayIntersectsSegment(point, coordinates[i], coordinates[i + 1])) {
        intersectCount++;
      }
    }
    if (_rayIntersectsSegment(point, coordinates.last, coordinates.first)) {
      intersectCount++;
    }
    return (intersectCount % 2 == 1); // Odd = Inside, Even = Outside
  }

  bool _rayIntersectsSegment(LatLng p, LatLng a, LatLng b) {
    LatLng aa = a;
    LatLng bb = b;
    if (aa.latitude > bb.latitude) {
      aa = b;
      bb = a;
    }
    if (p.latitude == aa.latitude || p.latitude == bb.latitude) {
      p = LatLng(p.latitude + 0.00001, p.longitude);
    }
    if ((p.latitude > bb.latitude) || (p.latitude < aa.latitude) ||
        (p.longitude > (aa.longitude > bb.longitude ? aa.longitude : bb.longitude))) {
      return false;
    }
    if (p.longitude < (aa.longitude < bb.longitude ? aa.longitude : bb.longitude)) {
      return true;
    }
    double mRed = (aa.latitude - bb.latitude) != 0 ? (aa.longitude - bb.longitude) / (aa.latitude - bb.latitude) : 0.0;
    double mBlue = (aa.latitude - p.latitude) != 0 ? (aa.longitude - p.longitude) / (aa.latitude - p.latitude) : 0.0;
    return mBlue >= mRed;
  }


  /// Create model from Firestore document
  factory PolygonModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final List<dynamic> coordinateList =
        data['coordinates'] ?? [];

    return PolygonModel(
      id: doc.id,

      type: data['type'] ?? 'Unknown',

      severity: data['severity'] ?? 'Low',

      color: data['color'] ?? 'red',

      coordinates: coordinateList.map((point) {
        return LatLng(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
        );
      }).toList(),

      createdAt:
      (data['createdAt'] as Timestamp?)
          ?.toDate() ??
          DateTime.now(),
    );
  }

  /// Convert model to Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type,

      'severity': severity,

      'color': color,

      'createdAt': Timestamp.fromDate(createdAt),

      'coordinates': coordinates
          .map(
            (point) => {
          'lat': point.latitude,
          'lng': point.longitude,
        },
      )
          .toList(),
    };
  }

  /// Polygon fill color
  Color get fillColor {
    switch (color.toLowerCase()) {
      case 'green':
        return Colors.green.withOpacity(0.35);

      case 'orange':
        return Colors.orange.withOpacity(0.35);

      case 'yellow':
        return Colors.yellow.withOpacity(0.35);

      case 'blue':
        return Colors.blue.withOpacity(0.35);

      default:
        return Colors.red.withOpacity(0.35);
    }
  }

  /// Polygon border color
  Color get strokeColor {
    switch (color.toLowerCase()) {
      case 'green':
        return Colors.green;

      case 'orange':
        return Colors.orange;

      case 'yellow':
        return Colors.yellow.shade700;

      case 'blue':
        return Colors.blue;

      default:
        return Colors.red;
    }
  }

  /// Google Maps Polygon ID
  PolygonId get polygonId => PolygonId(id);

  /// Create modified copy
  PolygonModel copyWith({
    String? id,
    String? type,
    String? severity,
    String? color,
    List<LatLng>? coordinates,
    DateTime? createdAt,
  }) {
    return PolygonModel(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      color: color ?? this.color,
      coordinates: coordinates ?? this.coordinates,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return '''
PolygonModel(
id: $id,
type: $type,
severity: $severity,
color: $color,
points: ${coordinates.length}
)
''';
  }
}