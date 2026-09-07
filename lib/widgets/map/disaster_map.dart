import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/polygon_model.dart';
import '../../Services/map_service.dart';
import 'polygon_layer.dart';
import 'marker_layer.dart';

class DisasterMap extends StatefulWidget {
  const DisasterMap({
    super.key,
    this.isAdmin = false,
    this.targetLat,    // Shelter Latitude
    this.targetLng,    // Shelter Longitude
    this.targetTitle,  // Shelter Name
  });

  final bool isAdmin;
  final double? targetLat;
  final double? targetLng;
  final String? targetTitle;

  @override
  State<DisasterMap> createState() => _DisasterMapState();
}

class _DisasterMapState extends State<DisasterMap> {
  bool _isPointInsidePolygon(LatLng point, List<LatLng> vertices) {
    int intersectCount = 0;
    for (int i = 0; i < vertices.length - 1; i++) {
      if (_rayIntersectsSegment(point, vertices[i], vertices[i + 1])) {
        intersectCount++;
      }
    }
    // Check last vertex to first vertex connection
    if (_rayIntersectsSegment(point, vertices.last, vertices.first)) {
      intersectCount++;
    }
    return (intersectCount % 2 == 1); // Odd means inside, even means outside
  }

  bool _rayIntersectsSegment(LatLng p, LatLng a, LatLng b) {
    if (a.latitude > b.latitude) {
      LatLng temp = a;
      a = b;
      b = temp;
    }
    if (p.latitude == a.latitude || p.latitude == b.latitude) {
      p = LatLng(p.latitude + 0.00001, p.longitude);
    }
    if ((p.latitude > b.latitude) || (p.latitude < a.latitude) ||
        (p.longitude >
            (a.longitude > b.longitude ? a.longitude : b.longitude))) {
      return false;
    }
    if (p.longitude < (a.longitude < b.longitude ? a.longitude : b.longitude)) {
      return true;
    }
    double mRed = (a.latitude - b.latitude) != 0 ? (a.longitude - b.longitude) /
        (a.latitude - b.latitude) : 0.0;
    double mBlue = (a.latitude - p.latitude) != 0 ? (a.longitude -
        p.longitude) / (a.latitude - p.latitude) : 0.0;
    return mBlue >= mRed;
  }

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

  //----------------------------------------------------------
  // Google Map Data
  //----------------------------------------------------------

  Set<Polygon> _polygons = {};

  Set<Marker> _markers = {};

  //----------------------------------------------------------
  // Firestore Models
  //----------------------------------------------------------

  List<PolygonModel> _affectedZones = [];

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
    _polygonSubscription =
        MapService.instance.getAffectedZones().listen((zones) {
          List<PolygonModel> filteredZones = zones;

          // If NOT admin, filter zones based on whether the citizen is inside the zone
          if (!widget.isAdmin && _currentLocation != null) {
            filteredZones = zones.where((zone) {
              return _isPointInsidePolygon(
                _currentLocation!,
                zone.coordinates,
              );
            }).toList();
          } else if (!widget.isAdmin && _currentLocation == null) {
            // If location isn't fetched yet, show no zones until location is ready
            filteredZones = [];
          }

          setState(() {
            _affectedZones = filteredZones;
            _polygons = PolygonLayer.buildPolygons(filteredZones);
          });
        });
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

      _updateAllMarkers();
      _loadAffectedZones();

      // Agar target shelter hai toh camera wahan focus ho, warna current location par
      if (_mapController != null) {
        if (widget.targetLat != null && widget.targetLng != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(widget.targetLat!, widget.targetLng!),
              15,
            ),
          );
        } else {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              currentPosition,
              14,
            ),
          );
        }
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

  void _startFirestoreListeners() {
    setState(() {
      _isLoading = false;
    });
  }
  //----------------------------------------------------------
  // Update All Markers (Current Location + Target Shelter)
  //----------------------------------------------------------

  void _updateAllMarkers() {
    Set<Marker> markersSet = {};

    // 1. Current Location Marker
    if (_currentLocation != null) {
      markersSet.add(
        MarkerLayer.buildCurrentLocationMarker(location: _currentLocation!),
      );
    }

    // 2. Target Shelter Marker (Agar home screen se pass hua hai)
    if (widget.targetLat != null && widget.targetLng != null) {
      markersSet.add(
        Marker(
          markerId: const MarkerId('target_shelter_marker'),
          position: LatLng(widget.targetLat!, widget.targetLng!),
          infoWindow: InfoWindow(
            title: widget.targetTitle ?? 'Help Center',
            snippet: 'Destination Shelter',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {
      _markers = markersSet;
    });
  } // <--- Yahan _updateAllMarkers function mukammal band ho gaya

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

            // Map load hone par agar shelter coordinates hain toh wahan zoom karein
            if (widget.targetLat != null && widget.targetLng != null) {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(widget.targetLat!, widget.targetLng!),
                  15,
                ),
              );
            } else if (_currentLocation != null) {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  _currentLocation!,
                  14,
                ),
              );
            }
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
