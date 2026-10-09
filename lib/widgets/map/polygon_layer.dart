import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/polygon_model.dart';

/// Converts PolygonModel objects into Google Maps Polygons.
///
/// This class DOES NOT communicate with Firebase.
/// It only builds Polygon objects for Google Maps.
class PolygonLayer {
  PolygonLayer._();

  /// Build all polygons
  static Set<Polygon> buildPolygons(
      List<PolygonModel> zones,
      ) {
    return zones.map((zone) => _buildPolygon(zone)).toSet();
  }

  /// Build a single polygon
  static Polygon _buildPolygon(
      PolygonModel zone,
      ) {
    return Polygon(
      polygonId: PolygonId(zone.id),

      points: zone.coordinates,

      strokeWidth: 3,

      strokeColor: zone.strokeColor,

      fillColor: zone.fillColor,

      geodesic: true,

      visible: true,

      consumeTapEvents: true,

      zIndex: 1,

      onTap: () {
        debugPrint(
          "Tapped: ${zone.type} | ${zone.severity}",
        );
      },
    );
  }

  //----------------------------------------------------------
  // Optional Helper Methods
  //----------------------------------------------------------

  /// Return polygon count
  static int totalPolygons(
      List<PolygonModel> zones,
      ) {
    return zones.length;
  }

  /// Filter only high severity polygons
  static List<PolygonModel> highSeverityZones(
      List<PolygonModel> zones,
      ) {
    return zones.where((zone) {
      return zone.severity.toLowerCase() == 'high';
    }).toList();
  }

  /// Filter by disaster type
  static List<PolygonModel> filterByType(
      List<PolygonModel> zones,
      String disasterType,
      ) {
    return zones.where((zone) {
      return zone.type.toLowerCase() ==
          disasterType.toLowerCase();
    }).toList();
  }

  /// Filter by color
  static List<PolygonModel> filterByColor(
      List<PolygonModel> zones,
      String color,
      ) {
    return zones.where((zone) {
      return zone.color.toLowerCase() ==
          color.toLowerCase();
    }).toList();
  }
}