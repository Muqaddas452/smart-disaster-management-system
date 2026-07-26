import 'dart:async';

import 'package:flutter/material.dart';
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

  });

  /// true = Admin Dashboard
  /// false = User App
  final bool isAdmin;

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
  // UI State
  //----------------------------------------------------------

  bool _isLoading = true;

  bool _locationPermissionGranted = false;

  //----------------------------------------------------------
  // Initial Camera Position
  //----------------------------------------------------------

  static const CameraPosition _initialCameraPosition =
  CameraPosition(
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
    _loadAffectedZones();
  }

  void _loadAffectedZones() {

    MapService.instance
        .getAffectedZones()
        .listen((zones) {

      setState(() {

        _affectedZones = zones;

        _polygons = zones.map((zone) {

          return Polygon(

            polygonId: zone.polygonId,

            points: zone.coordinates,

            strokeWidth: 4,

            strokeColor: zone.strokeColor,

            fillColor: zone.fillColor,

          );

        }).toSet();

      });

    });

  }
  //----------------------------------------------------------
  // Initialize Map
  //----------------------------------------------------------

  Future<void> _initializeMap() async {
    await _checkLocationPermission();

    await _getCurrentLocation();

    _startFirestoreListeners() ;

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

    // Check if location service is enabled
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

    // Check current permission
    permission = await Geolocator.checkPermission();

    // Request permission if denied
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

    // Permanently denied
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
      final Position position =
      await Geolocator.getCurrentPosition(
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

      // Move camera if map already exists
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            currentPosition,
            14,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "Error getting current location: $e",
      );
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

  // void _startFirestoreListeners() {
  //   _listenAffectedZones();
  //   _listenRescueTeams();
  // }

  //extra after delete

  void _startFirestoreListeners() {
    _affectedZones = [
      PolygonModel(
        id: 'zone1',
        type: 'Flood',
        severity: 'High',
        color: 'red',
        coordinates: const [
          LatLng(32.5865, 73.4918),
          LatLng(32.5890, 73.4950),
          LatLng(32.5850, 73.4980),
          LatLng(32.5820, 73.4930),
        ],
        createdAt: DateTime.now(),
      ),
    ];

    setState(() {
      _polygons = PolygonLayer.buildPolygons(_affectedZones);
      _markers = {};
      _isLoading = false;
    });
  }
  //----------------------------------------------------------
  // Listen Affected Zones
  //----------------------------------------------------------

  void _listenAffectedZones() {
    _polygonSubscription?.cancel();

    _polygonSubscription =
        _mapService.getAffectedZones().listen(
              (zones) {
            _affectedZones = zones;

            final polygons =
            PolygonLayer.buildPolygons(_affectedZones);

            if (!mounted) return;

            setState(() {
              _polygons = polygons;
            });
          },
          onError: (error) {
            debugPrint(
              "Affected Zones Error: $error",
            );
          },
        );
  }

  //----------------------------------------------------------
  // Listen Rescue Teams
  //----------------------------------------------------------

  void _listenRescueTeams() {
    _rescueSubscription?.cancel();

    _rescueSubscription =
        _mapService.getRescueTeams().listen(
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
            debugPrint(
              "Rescue Teams Error: $error",
            );

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
  // Build UI
  //----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        //------------------------------------------------------
        // Google Map
        //------------------------------------------------------

        GoogleMap(
          initialCameraPosition: _initialCameraPosition,

          polygons: _polygons,

          markers: _markers,

          myLocationEnabled: _locationPermissionGranted,

          myLocationButtonEnabled: false,

          zoomControlsEnabled: false,

          compassEnabled: true,

          mapToolbarEnabled: true,

          buildingsEnabled: true,

          trafficEnabled: false,

          indoorViewEnabled: false,

          mapType: MapType.normal,

          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;

            if (_currentLocation != null) {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  _currentLocation!,
                  14,
                ),
              );
            }
          },

          onCameraMove: (CameraPosition position) {
            // Reserved for future:
            // Admin monitoring
            // Nearby rescue search
            // Dynamic loading
          },

          onTap: (LatLng position) {
            debugPrint(
              "Map tapped: "
                  "${position.latitude}, "
                  "${position.longitude}",
            );
          },
        ),
        //------------------------------------------------------
        // Loading Indicator
        //------------------------------------------------------

        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),

        //------------------------------------------------------
        // Location Permission Warning
        //------------------------------------------------------

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
                    Icon(
                      Icons.location_off,
                      color: Colors.orange,
                    ),
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

        //------------------------------------------------------
        // Floating Buttons
        //------------------------------------------------------

        Positioned(
          right: 16,
          bottom: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              //------------------------------------------------
              // Current Location
              //------------------------------------------------

              FloatingActionButton(
                heroTag: "current_location",

                mini: true,

                onPressed: _moveToCurrentLocation,

                child: const Icon(Icons.my_location),
              ),

              const SizedBox(height: 12),

              //------------------------------------------------
              // Refresh Map
              //------------------------------------------------

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