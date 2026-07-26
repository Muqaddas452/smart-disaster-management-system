import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/rescue_team_model.dart';

/// Builds Google Map markers.
///
/// This class only converts models into markers.
/// It does NOT communicate with Firebase.
class MarkerLayer {
  MarkerLayer._();

  //----------------------------------------------------------
  // Build All Markers
  //----------------------------------------------------------

  static Set<Marker> buildMarkers({
    required List<RescueTeamModel> rescueTeams,
    LatLng? currentLocation,
    List<Marker> extraMarkers = const [],
  }) {
    final Set<Marker> markers = {};

    // Rescue Team Markers
    for (final team in rescueTeams) {
      markers.add(_buildRescueMarker(team));
    }

    // Current User Marker
    if (currentLocation != null) {
      markers.add(_buildCurrentLocationMarker(currentLocation));
    }

    // Additional markers (Shelters, Hospitals, etc.)
    markers.addAll(extraMarkers);

    return markers;
  }

  //----------------------------------------------------------
  // Rescue Team Marker
  //----------------------------------------------------------

  static Marker _buildRescueMarker(
      RescueTeamModel team,
      ) {
    return Marker(
      markerId: MarkerId(team.id),

      position: team.location,

      icon: _statusIcon(team.status),

      infoWindow: InfoWindow(
        title: team.name,
        snippet:
        "Vehicle: ${team.vehicle}\n"
            "Status: ${team.status}",
      ),
    );
  }

  //----------------------------------------------------------
  // Current User Marker
  //----------------------------------------------------------

  static Marker _buildCurrentLocationMarker(
      LatLng location,
      ) {
    return Marker(
      markerId: const MarkerId("current_location"),

      position: location,

      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      ),

      infoWindow: const InfoWindow(
        title: "Your Location",
      ),
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

  //----------------------------------------------------------
  // Rescue Team Colors
  //----------------------------------------------------------

  static BitmapDescriptor _statusIcon(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case "available":
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        );

      case "assigned":
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );

      case "en route":
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        );

      case "rescuing":
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );

      case "offline":
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        );

      default:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        );
    }
  }

  //----------------------------------------------------------
  // Helper Methods
  //----------------------------------------------------------

  static int totalTeams(
      List<RescueTeamModel> teams,
      ) {
    return teams.length;
  }

  static List<RescueTeamModel> availableTeams(
      List<RescueTeamModel> teams,
      ) {
    return teams.where((team) => team.isAvailable).toList();
  }

  static List<RescueTeamModel> assignedTeams(
      List<RescueTeamModel> teams,
      ) {
    return teams.where((team) => team.isAssigned).toList();
  }

  static List<RescueTeamModel> rescuingTeams(
      List<RescueTeamModel> teams,
      ) {
    return teams.where((team) => team.isRescuing).toList();
  }

  static List<RescueTeamModel> offlineTeams(
      List<RescueTeamModel> teams,
      ) {
    return teams.where((team) => team.isOffline).toList();
  }
}