import 'dart:async';

import 'package:flutter/foundation.dart'; // <-- Added this missing import
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/polygon_model.dart';
import '../../models/rescue_team_model.dart';
import '../../Services/map_service.dart';
import 'polygon_layer.dart';
import 'marker_layer.dart';

class DisasterMap extends StatefulWidget {
  const DisasterMap({
    super.key,
    this.isAdmin = false,
    this.zonesStream,
    this.isRescueView = false,
    this.initialCameraPosition,
    this.autoFollowLocation = true,
    this.showControls = true,
  });

  /// true = Admin Dashboard / Rescue Tasks tab
  /// false = User App / Rescue Affected-Zones tab
  final bool isAdmin;

  /// Optional override for where the polygons come from.
  ///
  /// If null, defaults to MapService.getAffectedZones() — the
  /// original behavior (Citizen app, Rescue "Affected Zones" tab).
  ///
  /// Pass MapService.getTaskZones(...) here for the Rescue
  /// "Tasks" map tab instead.
  final Stream<List<PolygonModel>>? zonesStream;

  /// true = wording on the "inside a zone" banner is written for
  /// a rescue team member/leader (reported zone + recommended
  /// action) instead of a citizen (evacuation safety tip).
  final bool isRescueView;

  /// Optional fixed camera target — used by the Home screen's
  /// compact alert-preview map to center on that specific alert
  /// instead of the device's current location.
  final CameraPosition? initialCameraPosition;

  /// When false, the map does NOT auto-animate to the device's
  /// current location on load. Used by the Home screen preview,
  /// which should stay centered on the alert, not the user.
  final bool autoFollowLocation;

  /// When false, hides the floating "my location" / "refresh"
  /// buttons — used for the small Home screen preview map.
  final bool showControls;

  @override
  State<DisasterMap> createState() => _DisasterMapState();
}

class _DisasterMapState extends State<DisasterMap> {
  //----------------------------------------------------------
  // Services
  //----------------------------------------------------------

  final MapService _mapService = MapService.instance;

  //----------------------------------------------------------
  // Google Map Controller
  //----------------------------------------------------------

  GoogleMapController? _mapController;

  //----------------------------------------------------------
  // Firestore Stream Subscriptions
  //----------------------------------------------------------

  StreamSubscription<List<PolygonModel>>? _polygonSubscription;
  StreamSubscription<List<RescueTeamModel>>? _rescueSubscription;

  //----------------------------------------------------------
  // Google Map Data
  //----------------------------------------------------------

  Set<Polygon> _polygons = {};

  Set<Marker> _markers = {};

  //----------------------------------------------------------
  // Firestore Models
  //----------------------------------------------------------

  List<PolygonModel> _affectedZones = [];

  List<RescueTeamModel> _rescueTeams = [];

  //----------------------------------------------------------
  // User Current Location
  //----------------------------------------------------------

  LatLng? _currentLocation;

  //----------------------------------------------------------
  // Zone the citizen is currently inside (null = safe / no active zone)
  //----------------------------------------------------------

  PolygonModel? _currentAlertZone;

  //----------------------------------------------------------
  // UI State
  //----------------------------------------------------------

  bool _isLoading = true;

  bool _locationPermissionGranted = false;

  //----------------------------------------------------------
  // Initial Camera Position
  //----------------------------------------------------------

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(32.5865, 73.4918),
    zoom: 15,
  );

  //----------------------------------------------------------
  // initState
  //----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  //----------------------------------------------------------
  // Initialize Map
  //----------------------------------------------------------

  Future<void> _initializeMap() async {
    await _checkLocationPermission();
    await _getCurrentLocation();
    _startFirestoreListeners();
  }

  //----------------------------------------------------------
  // Dispose
  //----------------------------------------------------------

  @override
  void dispose() {
    _polygonSubscription?.cancel();
    _rescueSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  //----------------------------------------------------------
  // Check Location Permission
  //----------------------------------------------------------

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoading = false;
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _locationPermissionGranted = true;
      });
    }
  }

  //----------------------------------------------------------
  // Get Current Location
  //----------------------------------------------------------

  Future<void> _getCurrentLocation() async {
    if (!_locationPermissionGranted) {
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng currentPosition = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = currentPosition;
      });

      _reloadCurrentLocationMarker();
      _checkIfInsideAffectedZone();

      if (widget.autoFollowLocation && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            currentPosition,
            14,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error getting current location: $e");
    }
  }

  //----------------------------------------------------------
  // Move Camera to Current Location
  //----------------------------------------------------------

  Future<void> _moveToCurrentLocation() async {
    if (_currentLocation == null || _mapController == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        _currentLocation!,
        15,
      ),
    );
  }

  //----------------------------------------------------------
  // Refresh Map
  //----------------------------------------------------------

  Future<void> _refreshMap() async {
    await _getCurrentLocation();
  }

  //----------------------------------------------------------
  // Start Firestore Listeners
  //----------------------------------------------------------

  void _startFirestoreListeners() {
    _listenAffectedZones();

    if (widget.isAdmin) {
      _listenRescueTeams();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //----------------------------------------------------------
  // Listen Affected Zones / Task Zones
  //----------------------------------------------------------

  void _listenAffectedZones() {
    _polygonSubscription?.cancel();

    final Stream<List<PolygonModel>> stream =
        widget.zonesStream ?? _mapService.getAffectedZones();

    _polygonSubscription = stream.listen(
          (zones) {
        _affectedZones = zones;

        final polygons = PolygonLayer.buildPolygons(_affectedZones);

        if (!mounted) return;

        setState(() {
          _polygons = polygons;
        });

        _checkIfInsideAffectedZone();
      },
      onError: (error) {
        debugPrint("Zones Error: $error");
      },
    );
  }

  //----------------------------------------------------------
  // Listen Rescue Teams
  //----------------------------------------------------------

  void _listenRescueTeams() {
    _rescueSubscription?.cancel();

    _rescueSubscription = _mapService.getRescueTeams().listen(
          (teams) {
        _rescueTeams = teams;

        final markers = MarkerLayer.buildMarkers(
          rescueTeams: _rescueTeams,
          currentLocation: _currentLocation,
        );

        if (!mounted) return;

        setState(() {
          _markers = markers;
          _isLoading = false;
        });
      },
      onError: (error) {
        debugPrint("Rescue Teams Error: $error");

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  //----------------------------------------------------------
  // Reload Current Location Marker
  //----------------------------------------------------------

  void _reloadCurrentLocationMarker() {
    _markers = MarkerLayer.buildMarkers(
      rescueTeams: _rescueTeams,
      currentLocation: _currentLocation,
    );

    if (!mounted) return;

    setState(() {});
  }

  //----------------------------------------------------------
  // Point-in-Polygon Check
  //----------------------------------------------------------

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool isInside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final bool intersects =
          ((polygon[i].longitude > point.longitude) !=
              (polygon[j].longitude > point.longitude)) &&
              (point.latitude <
                  (polygon[j].latitude - polygon[i].latitude) *
                      (point.longitude - polygon[i].longitude) /
                      (polygon[j].longitude - polygon[i].longitude) +
                      polygon[i].latitude);

      if (intersects) {
        isInside = !isInside;
      }

      j = i;
    }

    return isInside;
  }

  //----------------------------------------------------------
  // Check if current location is inside ANY affected zone
  //----------------------------------------------------------

  void _checkIfInsideAffectedZone() {
    if (_currentLocation == null || _affectedZones.isEmpty) {
      if (_currentAlertZone != null) {
        setState(() => _currentAlertZone = null);
      }
      return;
    }

    PolygonModel? matchedZone;

    for (final zone in _affectedZones) {
      if (_isPointInPolygon(_currentLocation!, zone.coordinates)) {
        matchedZone = zone;
        break;
      }
    }

    if (matchedZone?.id != _currentAlertZone?.id) {
      setState(() {
        _currentAlertZone = matchedZone;
      });
    }
  }

  //----------------------------------------------------------
  // Safety tip text based on disaster type
  //----------------------------------------------------------

  String _safetyTipFor(String type) {
    switch (type.toLowerCase()) {
      case 'flood':
        return 'Move to higher ground. Avoid flowing water.';
      case 'earthquake':
        return 'Stay away from buildings. Move to open ground.';
      case 'heatwave':
        return 'Stay hydrated. Avoid direct sun exposure.';
      case 'storm':
        return 'Stay indoors. Avoid windows and loose objects.';
      default:
        return 'Follow official instructions and stay alert.';
    }
  }

  //----------------------------------------------------------
  // Recommended action text for rescue teams
  //----------------------------------------------------------

  String _rescueActionFor(String type) {
    switch (type.toLowerCase()) {
      case 'flood':
        return 'Prepare water rescue equipment and coordinate evacuation support.';
      case 'earthquake':
        return 'Prepare search & rescue teams and check structural hazards.';
      case 'heatwave':
        return 'Prepare medical support for heat-related emergencies.';
      case 'storm':
        return 'Prepare for wind damage response and power outage support.';
      default:
        return 'Coordinate with control room and stay on standby.';
    }
  }

  //----------------------------------------------------------
  // Build UI
  //----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: widget.initialCameraPosition ?? _initialCameraPosition,
          polygons: _polygons,
          markers: _markers,
          myLocationEnabled: _locationPermissionGranted,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
            ),
          },
          compassEnabled: true,
          mapToolbarEnabled: true,
          buildingsEnabled: true,
          trafficEnabled: false,
          indoorViewEnabled: false,
          mapType: MapType.normal,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;

            if (widget.autoFollowLocation && _currentLocation != null) {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  _currentLocation!,
                  14,
                ),
              );
            }
          },
          onCameraMove: (CameraPosition position) {},
          onTap: (LatLng position) {
            debugPrint(
              "Map tapped: ${position.latitude}, ${position.longitude}",
            );
          },
        ),

        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),

        if (!_locationPermissionGranted)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.orange.shade100,
              elevation: 4,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Location permission denied.\nCurrent location is unavailable.",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (!widget.isAdmin && _currentAlertZone != null)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.red.shade50,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.isRescueView
                                ? "${_currentAlertZone!.severity.toUpperCase()} "
                                "${_currentAlertZone!.type.toUpperCase()} REPORTED"
                                : "${_currentAlertZone!.severity.toUpperCase()} "
                                "${_currentAlertZone!.type.toUpperCase()} RISK",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isRescueView
                          ? "This zone has been reported as affected. Ensure your team is prepared to respond."
                          : "You are currently inside an affected zone.",
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isRescueView
                          ? "Recommended: ${_rescueActionFor(_currentAlertZone!.type)}"
                          : "Safety tip: ${_safetyTipFor(_currentAlertZone!.type)}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (widget.showControls)
          Positioned(
            right: 16,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "current_location",
                  mini: true,
                  onPressed: _moveToCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: "refresh_map",
                  mini: true,
                  onPressed: _refreshMap,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
      ],
    );
  }
}