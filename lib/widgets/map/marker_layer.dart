import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds Google Map markers for Citizen App.
///
/// Handles Current Location, Shelters, Hospitals, and Disaster Centers.
class MarkerLayer {
  MarkerLayer._();

  //----------------------------------------------------------
  // Current User Marker
  //----------------------------------------------------------

  static Marker buildCurrentLocationMarker({
    required LatLng location,
  }) {
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
}