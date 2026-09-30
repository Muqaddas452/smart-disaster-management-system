import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smartdisaster/database/map_icon_helper.dart';

/// Builds Google Map markers for Citizen App.
///
/// Handles Current Location, Shelters, Hospitals, and Disaster Centers.
class MarkerLayer {
  MarkerLayer._();

  //----------------------------------------------------------
  // Current User Marker
  //----------------------------------------------------------

  /// 1. Current / Rescue Member Location Marker (Clean Person Icon - Solid, No Circle)
  static Future<Marker> buildCurrentLocationMarker({
    required LatLng location,
    Color iconColor = Colors.blue, // Aap blue ya green rakh sakti hain
  }) async {
    final customIcon = await createDirectIconMarker(
      Icons.person,
      iconColor,
      size: 60,
    );

    return Marker(
      markerId: const MarkerId('current_location_marker'),
      position: location,
      icon: customIcon,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(title: 'Your Location'),
    );
  }

  // 2. Home Screen Small Map ke liye -> Active Alert Marker (Red Alert Icon)
  static Future<Marker> buildAlertMarker({
    required LatLng location,
    required String alertTitle,
  }) async {
    final customIcon = await createDirectIconMarker(
      Icons.warning_rounded,
      Colors.red, // Red color for alert
      size: 70,
    );

    return Marker(
      markerId: const MarkerId('home_active_alert_marker'),
      position: location,
      icon: customIcon,
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: alertTitle, snippet: 'Active Disaster Alert'),
    );
  }
  // 3. Main Map / Tasks Screen ke liye -> Task Type ke mutabiq Marker (Storm, Flood, Heatwave etc.)
  static Future<Marker> buildTaskMarker({
    required String taskId,
    required LatLng location,
    required String taskType,
  }) async {
    IconData taskIcon = getTaskTypeIcon(taskType);

    // Task ke type ke mutabiq color select hoga
    Color taskColor = Colors.orange.shade800;
    if (taskType.toLowerCase().contains('heatwave')) {
      taskColor = Colors.amber; // Heatwave ke liye yellow/amber
    } else if (taskType.toLowerCase().contains('storm')) {
      taskColor = Colors.blueGrey; // Storm ke liye
    } else if (taskType.toLowerCase().contains('flood')) {
      taskColor = Colors.blue; // Flood ke liye
    }

    final customIcon = await createDirectIconMarker(
      taskIcon,
      taskColor,
      size: 95,
    );

    return Marker(
      markerId: MarkerId('task_marker_$taskId'),
      position: location,
      icon: customIcon,
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: taskType, snippet: 'Assigned Task Location'),
    );
  }
  //----------------------------------------------------------
  // Shelter Marker
  //----------------------------------------------------------

  static Marker buildShelterMarker({
    required String id,
    required String name,
    required LatLng location,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueYellow,
      ),
      infoWindow: InfoWindow(
        title: name,
        snippet: "Shelter",
      ),
    );
  }

  //----------------------------------------------------------
  // Hospital Marker
  //----------------------------------------------------------

  static Marker buildHospitalMarker({
    required String id,
    required String name,
    required LatLng location,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRose,
      ),
      infoWindow: InfoWindow(
        title: name,
        snippet: "Hospital",
      ),
    );
  }

  //----------------------------------------------------------
  // Disaster Center Marker
  //----------------------------------------------------------

  static Marker buildDisasterMarker({
    required String id,
    required String title,
    required LatLng location,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      ),
      infoWindow: InfoWindow(
        title: title,
        snippet: "Affected Area",
      ),
    );
  }
}