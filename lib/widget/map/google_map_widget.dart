import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  // ============================================================
  // AI PREDICTIONS
  // ============================================================

  // Latest AI prediction for every district/city.
  Map<String, Map<String, dynamic>> _predictionsByDistrict = {};

  // Currently displayed prediction.
  Map<String, dynamic>? _selectedPrediction;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _predictionSubscription;

  // ============================================================
  // HOVER STATE
  // ============================================================

  // Prevents repeated async hover calculations.
  bool _checkingHover = false;

  // Last zone shown in the AI card.
  String? _hoveredZoneId;

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

  // ============================================================
  // FIREBASE LISTENERS
  // ============================================================

  void _listenToFirebase() {
    // ----------------------------------------------------------
    // REPORTS
    // ----------------------------------------------------------

    _reportSubscription = _reportService.getReports().listen((reports) {
      _reports = reports;
      _updateMarkers();
    });

    // ----------------------------------------------------------
    // RESCUE TEAMS
    // ----------------------------------------------------------

    _teamSubscription = _rescueTeamService.getRescueTeams().listen((teams) {
      _teams = teams;
      _updateMarkers();
    });

    // ----------------------------------------------------------
    // SHELTERS
    // ----------------------------------------------------------

    _shelterService.getShelters().listen((data) {
      if (!mounted) return;

      setState(() {
        _shelters = data;
      });

      _updateMarkers();
    });

    // ----------------------------------------------------------
    // AFFECTED ZONES
    // ----------------------------------------------------------

    _zoneSubscription =
        _affectedZoneService.getAffectedZones().listen((zones) {
          _zones = zones;

          _updateMarkers();
          _updateCircles();

          // Automatically select first matching prediction
          // only when nothing is currently selected.
          if (_selectedPrediction == null && zones.isNotEmpty) {
            for (final zone in zones) {
              final prediction = _getPredictionForZone(zone);

              if (prediction != null) {
                _selectZonePrediction(zone);
                break;
              }
            }
          }
        });

    // ----------------------------------------------------------
    // AI ALERTS
    // ----------------------------------------------------------

    _predictionSubscription = FirebaseFirestore.instance
        .collection('alerts')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final Map<String, Map<String, dynamic>> predictions = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final district = _normalizeLocation(
          data['district'],
        );

        if (district.isEmpty) {
          continue;
        }

        final currentTime = _parseDateTime(data['time']);

        final existing = predictions[district];

        if (existing == null) {
          predictions[district] = data;
        } else {
          final existingTime = _parseDateTime(
            existing['time'],
          );

          if (currentTime != null &&
              (existingTime == null ||
                  currentTime.isAfter(existingTime))) {
            predictions[district] = data;
          }
        }
      }

      setState(() {
        _predictionsByDistrict = predictions;
      });

      // --------------------------------------------------------
      // Update currently displayed zone prediction
      // --------------------------------------------------------

      if (_hoveredZoneId != null) {
        AffectedZone? hoveredZone;

        for (final zone in _zones) {
          if (zone.id == _hoveredZoneId) {
            hoveredZone = zone;
            break;
          }
        }

        if (hoveredZone != null) {
          final updatedPrediction =
          _getPredictionForZone(hoveredZone);

          if (updatedPrediction != null) {
            setState(() {
              _selectedPrediction = updatedPrediction;
            });
          }
        }
      }

      // --------------------------------------------------------
      // Fallback: first matching zone
      // --------------------------------------------------------

      if (_selectedPrediction == null && _zones.isNotEmpty) {
        for (final zone in _zones) {
          final prediction = _getPredictionForZone(zone);

          if (prediction != null) {
            setState(() {
              _selectedPrediction = prediction;
            });
            break;
          }
        }
      }
    });
  }

  // ============================================================
  // LOCATION NORMALIZATION
  // ============================================================

  String _normalizeLocation(dynamic value) {
    if (value == null) return '';

    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ============================================================
  // GET PREDICTION FOR SPECIFIC ZONE
  // ============================================================

  Map<String, dynamic>? _getPredictionForZone(
      AffectedZone zone,
      ) {
    final city = _normalizeLocation(zone.city);

    if (city.isEmpty) {
      return null;
    }

    // Direct match:
    // affectedZones.city == alerts.district
    final directPrediction = _predictionsByDistrict[city];

    if (directPrediction != null) {
      return directPrediction;
    }

    // Fallback:
    // Lahore District <-> Lahore
    for (final entry in _predictionsByDistrict.entries) {
      final alertDistrict = entry.key;

      if (alertDistrict == city ||
          alertDistrict.contains(city) ||
          city.contains(alertDistrict)) {
        return entry.value;
      }
    }

    return null;
  }

  // ============================================================
  // SELECT ZONE PREDICTION
  // ============================================================

  void _selectZonePrediction(AffectedZone zone) {
    final prediction = _getPredictionForZone(zone);

    if (prediction == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _selectedPrediction = prediction;
      _hoveredZoneId = zone.id;
    });
  }

  // ============================================================
  // GET ZONE RADIUS
  // ============================================================

  double _getZoneRadius(AffectedZone zone) {
    switch (zone.riskLevel.toLowerCase()) {
      case "critical":
        return 15000;

      case "high":
        return 10000;

      case "medium":
        return 5000;

      case "low":
        return 2000;

      default:
        return 3000;
    }
  }

  // ============================================================
  // MAP HOVER DETECTION
  // ============================================================

  Future<void> _handleMapHover(
      PointerHoverEvent event,
      BoxConstraints constraints,
      ) async {
    if (_mapController == null ||
        !_mapReady ||
        _zones.isEmpty ||
        _checkingHover) {
      return;
    }

    _checkingHover = true;

    try {
      final RenderBox? renderBox =
      context.findRenderObject() as RenderBox?;

      if (renderBox == null) {
        return;
      }

      // Mouse position relative to this widget.
      final localPosition = renderBox.globalToLocal(
        event.position,
      );

      // The map itself starts at the top-left of the Stack.
      final mapX = localPosition.dx;
      final mapY = localPosition.dy;

      final devicePixelRatio =
      MediaQuery.devicePixelRatioOf(context);

      final pointerScreenX =
          mapX * devicePixelRatio;

      final pointerScreenY =
          mapY * devicePixelRatio;

      AffectedZone? matchedZone;

      double closestDistance = double.infinity;

      for (final zone in _zones) {
        final parts = zone.coordinates.split(',');

        if (parts.length != 2) {
          continue;
        }

        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());

        if (lat == null || lng == null) {
          continue;
        }

        // Get zone center on screen.
        final centerScreen =
        await _mapController!.getScreenCoordinate(
          LatLng(lat, lng),
        );

        // Calculate a point exactly "radius" meters north
        // of the zone center.
        final radiusMeters = _getZoneRadius(zone);

        final radiusLat =
            lat + (radiusMeters / 111320.0);

        final radiusScreen =
        await _mapController!.getScreenCoordinate(
          LatLng(radiusLat, lng),
        );

        final centerX = centerScreen.x.toDouble();
        final centerY = centerScreen.y.toDouble();

        final radiusX = radiusScreen.x.toDouble();
        final radiusY = radiusScreen.y.toDouble();

        final screenRadius = math.sqrt(
          math.pow(radiusX - centerX, 2) +
              math.pow(radiusY - centerY, 2),
        );

        if (screenRadius <= 0) {
          continue;
        }

        final distance = math.sqrt(
          math.pow(pointerScreenX - centerX, 2) +
              math.pow(pointerScreenY - centerY, 2),
        );

        if (distance <= screenRadius &&
            distance < closestDistance) {
          closestDistance = distance;
          matchedZone = zone;
        }
      }

      if (!mounted) return;

      // --------------------------------------------------------
      // Cursor is inside an affected zone
      // --------------------------------------------------------

      if (matchedZone != null) {
        if (_hoveredZoneId != matchedZone.id) {
          _selectZonePrediction(matchedZone);
        }
      }
    } catch (e) {
      debugPrint(
        "Zone hover detection error: $e",
      );
    } finally {
      _checkingHover = false;
    }
  }

  // ============================================================
  // WHEN CURSOR LEAVES MAP
  // ============================================================

  void _handleMapExit(PointerExitEvent event) {
    // Do not clear the card.
    //
    // This keeps the last selected zone prediction visible,
    // instead of making the card disappear whenever the cursor
    // briefly leaves the map.
  }

  // ============================================================
  // FOCUS LOCATION
  // ============================================================

  Future<void> _focusOnSelectedLocation() async {
    if (_mapController == null) return;

    if (widget.focusLatitude == null ||
        widget.focusLongitude == null) {
      return;
    }

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

  // ============================================================
  // UPDATE MARKERS
  // ============================================================

  void _updateMarkers() {
    final Set<Marker> markers = {};

    //--------------------------------------------------
    // Shelter Markers
    //--------------------------------------------------

    final hasActiveDisaster = _zones.any(
          (zone) => zone.status.toLowerCase() == "active",
    );

    if (hasActiveDisaster) {
      for (final shelter in _shelters) {
        if (shelter.latitude == 0 ||
            shelter.longitude == 0) {
          continue;
        }

        markers.add(
          Marker(
            markerId: MarkerId(
              "shelter_${shelter.id}",
            ),
            position: LatLng(
              shelter.latitude,
              shelter.longitude,
            ),
            icon: shelterIcon,
            infoWindow: InfoWindow(
              title: shelter.name,
              snippet:
              "${shelter.city}\nAvailable: ${shelter.available}",
            ),
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
          onTap: () {
            if (!mounted) return;

            setState(() {
              _selectedPrediction = {
                'disaster': report.emergencyType,
                'risk': report.severity,
                'confidence': null,
                'district': report.reporterName,
                'time': null,
              };

              _hoveredZoneId = null;
            });
          },
        ),
      );
    }

    //--------------------------------------------------
    // Selected Location
    //--------------------------------------------------

    if (widget.focusLatitude != null &&
        widget.focusLongitude != null &&
        !_shelters.any(
              (s) =>
          s.latitude == widget.focusLatitude &&
              s.longitude == widget.focusLongitude,
        )) {
      markers.add(
        Marker(
          markerId: const MarkerId(
            "selected_location",
          ),
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
          markerId: MarkerId(
            "team_${team.id}",
          ),
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

  // ============================================================
  // UPDATE AFFECTED ZONE CIRCLES
  // ============================================================

  void _updateCircles() {
    final Set<Circle> circles = {};

    for (final zone in _zones) {
      final parts = zone.coordinates.split(',');

      if (parts.length != 2) continue;

      final lat = double.tryParse(
        parts[0].trim(),
      );

      final lng = double.tryParse(
        parts[1].trim(),
      );

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

      final radius = _getZoneRadius(zone);

      circles.add(
        Circle(
          circleId: CircleId(zone.id),
          center: LatLng(lat, lng),
          radius: radius,
          fillColor: color.withOpacity(.30),
          strokeColor: color,
          strokeWidth: 3,

          // Click still works as before.
          onTap: () {
            _selectZonePrediction(zone);
          },
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _circles = circles;
    });
  }

  // ============================================================
  // PARSE CONFIDENCE
  // ============================================================

  double? _parseConfidence(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value
          .toString()
          .replaceAll('%', '')
          .trim(),
    );
  }

  // ============================================================
  // PARSE DATE/TIME
  // ============================================================

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // FIT ALL MARKERS
  // ============================================================

  void _fitAllMarkers() {
    if (_markers.isEmpty ||
        _mapController == null) {
      return;
    }

    try {
      double minLat =
          _markers.first.position.latitude;

      double maxLat =
          _markers.first.position.latitude;

      double minLng =
          _markers.first.position.longitude;

      double maxLng =
          _markers.first.position.longitude;

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
            southwest: LatLng(
              minLat,
              minLng,
            ),
            northeast: LatLng(
              maxLat,
              maxLng,
            ),
          ),
          80,
        ),
      );
    } catch (e) {
      debugPrint(
        "Google Map Error: $e",
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _reportSubscription?.cancel();
    _teamSubscription?.cancel();
    _zoneSubscription?.cancel();
    _predictionSubscription?.cancel();

    _mapController?.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ======================================================
        // MAP + HOVER DETECTION
        // ======================================================

        MouseRegion(
          onHover: (event) {
            final renderBox =
            context.findRenderObject();

            if (renderBox is! RenderBox) {
              return;
            }

            final size = renderBox.size;

            _handleMapHover(
              event,
              BoxConstraints.tight(size),
            );
          },
          onExit: _handleMapExit,
          child: ClipRRect(
            borderRadius:
            BorderRadius.circular(12),
            child: SizedBox.expand(
              child: !_mapReady
                  ? const Center(
                child:
                CircularProgressIndicator(),
              )
                  : GoogleMap(
                initialCameraPosition:
                _initialPosition,

                mapType:
                MapType.normal,

                markers: _markers,

                polygons:
                _polygons,

                circles:
                _circles,

                zoomControlsEnabled:
                true,

                compassEnabled:
                true,

                myLocationEnabled:
                false,

                myLocationButtonEnabled:
                false,

                trafficEnabled:
                false,

                buildingsEnabled:
                true,

                onMapCreated:
                    (controller) async {
                  _mapController =
                      controller;

                  await _focusOnSelectedLocation();
                },
              ),
            ),
          ),
        ),

        // ========================================================
        // AI PREDICTION CARD
        // ========================================================

        if (_selectedPrediction != null)
          Positioned(
            top: 20,
            right: 20,
            child: AIPredictionCard(
              disaster:
              (_selectedPrediction![
              'disaster'] ??
                  _selectedPrediction![
                  'raw_disaster_type'] ??
                  'Unknown')
                  .toString(),

              risk:
              (_selectedPrediction![
              'risk'] ??
                  _selectedPrediction![
                  'raw_severity'] ??
                  'Unknown')
                  .toString(),

              confidence:
              _parseConfidence(
                _selectedPrediction![
                'confidence'],
              ),

              location:
              (_selectedPrediction![
              'district'] ??
                  '')
                  .toString(),

              updatedAt:
              _parseDateTime(
                _selectedPrediction![
                'time'],
              ),
            ),
          ),
      ],
    );
  }
}