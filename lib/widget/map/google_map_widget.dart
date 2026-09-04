import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../model/affected_zone_model.dart';
import '../../services/affected_zone_service.dart';
import '../../model/report_model.dart';
import '../../model/rescue_team_model.dart';
import '../../model/shelter_model.dart';
import '../../widget/shelter_details_dialog.dart';

import '../../services/report_service.dart';
import '../../services/rescue_team_service.dart';
import '../../services/shelter_service.dart';

import 'ai_prediction_card.dart';
class GoogleMapWidget extends StatefulWidget {

  final double? focusLatitude;
  final double? focusLongitude;
  final String? focusTitle;

  const GoogleMapWidget({
    super.key,
    this.focusLatitude,
    this.focusLongitude,
    this.focusTitle,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _mapController;

  final ReportService _reportService = ReportService();
  final RescueTeamService _rescueTeamService = RescueTeamService();
  final AffectedZoneService _affectedZoneService = AffectedZoneService();
  final ShelterService _shelterService = ShelterService();

  StreamSubscription<List<Report>>? _reportSubscription;
  StreamSubscription<List<RescueTeam>>? _teamSubscription;
  StreamSubscription<List<AffectedZone>>? _zoneSubscription;

  List<Report> _reports = [];
  List<RescueTeam> _teams = [];
  List<AffectedZone> _zones = [];
  List<ShelterModel> _shelters = [];

  bool _mapReady = false;

  BitmapDescriptor floodIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor earthquakeIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor heatwaveIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor rescueIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor shelterIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor stormIcon = BitmapDescriptor.defaultMarker;

  Set<Marker> _markers = {};

  Set<Polygon> _polygons = {};

  Set<Circle> _circles = {};

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(30.3753, 69.3451),
    zoom: 5.5,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _loadIcons();

        _listenToFirebase();

    if (mounted) {
      setState(() {
        _mapReady = true;
      });
    }
  }

  Future<void> _loadIcons() async {
    floodIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/icons/flood.png",
    );

    earthquakeIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/icons/earthquake.png",
    );

    heatwaveIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/icons/heatwave.png",
    );

    rescueIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/icons/rescue.png",
    );

    stormIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/icons/storm.png",
    );

    shelterIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(64, 64)),
      "assets/icons/shelter.png",
    );
  }
  void _listenToFirebase() {
    _reportSubscription = _reportService.getReports().listen((reports) {
      _reports = reports;
      _updateMarkers();
    });

    _teamSubscription = _rescueTeamService.getRescueTeams().listen((teams) {
      _teams = teams;
      _updateMarkers();
    });
    _shelterService.getShelters().listen((data) {
      if (!mounted) return;

      setState(() {
        _shelters = data;
      });

      _updateMarkers();
    });
    _zoneSubscription =
        _affectedZoneService.getAffectedZones().listen((zones) {

          _zones = zones;

          // Update markers because shelter visibility
          // depends on disaster status.
          _updateMarkers();

          // Update affected-zone circles.
          _updateCircles();

        });
  }
  Future<void> _focusOnSelectedLocation() async {

    if (_mapController == null) return;

    if (widget.focusLatitude == null ||
        widget.focusLongitude == null) return;

    await _mapController!.animateCamera(

      CameraUpdate.newCameraPosition(

        CameraPosition(

          target: LatLng(
            widget.focusLatitude!,
            widget.focusLongitude!,
          ),

          zoom: 14,

        ),

      ),

    );
  }
  void _updateMarkers() {
    final Set<Marker> markers = {};

//--------------------------------------------------
// Shelter Markers
// Show shelters ONLY when an active disaster exists
//--------------------------------------------------

    final hasActiveDisaster = _zones.any(
          (zone) => zone.status.toLowerCase() == "active",
    );

    if (hasActiveDisaster) {
      for (final shelter in _shelters) {

        // Ignore shelters without valid coordinates
        if (shelter.latitude == 0 || shelter.longitude == 0) {
          continue;
        }

        markers.add(
          Marker(
            markerId: MarkerId("shelter_${shelter.id}"),

            // Shelter location
            position: LatLng(
              shelter.latitude,
              shelter.longitude,
            ),

            // Use your shelter.png
            icon: shelterIcon,

            // Information shown when shelter is tapped
            infoWindow: InfoWindow(
              title: shelter.name,
              snippet:
              "${shelter.city}\nAvailable: ${shelter.available}",
            ),

            // Open shelter details
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => ShelterDetailsDialog(
                  shelter: shelter,
                ),
              );
            },
          ),
        );
      }
    }
    //--------------------------------------------------
    // Disaster Reports
    //--------------------------------------------------

    for (final report in _reports) {
      BitmapDescriptor icon = floodIcon;

      switch (report.emergencyType.toLowerCase()) {
        case "earthquake":
          icon = earthquakeIcon;
          break;

        case "heatwave":
          icon = heatwaveIcon;
          break;

        case "storm":
          icon = stormIcon;
          break;

        case "flood":
        default:
          icon = floodIcon;
      }

      markers.add(
        Marker(
          markerId: MarkerId(report.id),
          position: LatLng(
            report.latitude,
            report.longitude,
          ),
          icon: icon,
          infoWindow: InfoWindow(
            title: report.emergencyType,
            snippet:
            "${report.reporterName} • ${report.severity}",
          ),
        ),
      );
    }

    //--------------------------------------------------
    // Selected Zone
    //--------------------------------------------------

    // Only add the extra marker if it isn't a shelter
    if (widget.focusLatitude != null &&
        widget.focusLongitude != null &&
        !_shelters.any((s) =>
        s.latitude == widget.focusLatitude &&
            s.longitude == widget.focusLongitude)) {

      markers.add(
        Marker(
          markerId: const MarkerId("selected_location"),
          position: LatLng(
            widget.focusLatitude!,
            widget.focusLongitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: widget.focusTitle,
          ),
        ),
      );
    }

    //--------------------------------------------------
// Rescue Teams
//--------------------------------------------------

    for (final team in _teams) {

      if (team.latitude == 0 ||
          team.longitude == 0 ||
          team.latitude < -90 ||
          team.latitude > 90 ||
          team.longitude < -180 ||
          team.longitude > 180) {
        continue;
      }

      markers.add(
        Marker(
          markerId: MarkerId("team_${team.id}"),
          position: LatLng(
            team.latitude,
            team.longitude,
          ),
          icon: rescueIcon,
          infoWindow: InfoWindow(
            title: team.teamName,
            snippet: team.status,
          ),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _markers = markers;
    });

    _updateCircles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitAllMarkers();
    });
  }

  void _updateCircles() {
    final Set<Circle> circles = {};

    //--------------------------------------------------
    // Affected Zones
    //--------------------------------------------------

    for (final zone in _zones) {
      final parts = zone.coordinates.split(',');

      if (parts.length != 2) continue;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat == null || lng == null) continue;

      Color color = Colors.green;

      switch (zone.riskLevel.toLowerCase()) {
        case "critical":
          color = Colors.purple;
          break;

        case "high":
          color = Colors.red;
          break;

        case "medium":
          color = Colors.orange;
          break;

        default:
          color = Colors.green;
      }

      double radius;

      switch (zone.riskLevel.toLowerCase()) {
        case "critical":
          radius = 15000; // 15 km
          break;

        case "high":
          radius = 10000; // 10 km
          break;

        case "medium":
          radius = 5000; // 5 km
          break;

        case "low":
          radius = 2000; // 2 km
          break;

        default:
          radius = 3000; // Default
      }
      circles.add(
        Circle(
          circleId: CircleId(zone.id),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: color.withOpacity(.30),
          strokeColor: color,
          strokeWidth: 3,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _circles = circles;
    });
  }


  void _fitAllMarkers() {

    if (_markers.isEmpty || _mapController == null) {
      return;
    }

    try {

      double minLat = _markers.first.position.latitude;
      double maxLat = _markers.first.position.latitude;

      double minLng = _markers.first.position.longitude;
      double maxLng = _markers.first.position.longitude;

      for (final marker in _markers) {

        final lat = marker.position.latitude;
        final lng = marker.position.longitude;

        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;

        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80,
        ),
      );

    } catch (e) {

      debugPrint("Google Map Error: $e");

    }
  }
  @override
  void dispose() {
    _reportSubscription?.cancel();
    _teamSubscription?.cancel();
    _zoneSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.expand(
            child: !_mapReady
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : GoogleMap(
              initialCameraPosition: _initialPosition,

              mapType: MapType.normal,

              markers: _markers,

              polygons: _polygons,

              circles: _circles,

              zoomControlsEnabled: true,

              compassEnabled: true,

              myLocationEnabled: false,

              myLocationButtonEnabled: false,

              trafficEnabled: false,

              buildingsEnabled: true,

              onMapCreated: (controller) async {

                _mapController = controller;

                await _focusOnSelectedLocation();

              },
            ),
          ),
        ),

        const Positioned(
          top: 20,
          right: 20,
          child: AIPredictionCard(),
        ),

      ],
    );
  }
}