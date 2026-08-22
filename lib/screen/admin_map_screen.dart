import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Import your models and services here
// import 'package:your_app/model/rescue_team_model.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};

  // Default initial camera position (Centred on your primary area of operations)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(40.7128, -74.0060),
    zoom: 11.5,
  );

  @override
  void initState() {
    super.initState();
    _loadLiveMapData();
  }

  /// In production, switch this to listen to your StreamBuilder / Firestore map services.
  void _loadLiveMapData() {
    // 1. Mock Disaster Incident Reports (Red Markers)
    final disasterReports = [
      {'id': 'disaster_1', 'title': 'Flooding Incident', 'lat': 40.7128, 'lng': -74.0060, 'type': 'Flood'},
      {'id': 'disaster_2', 'title': 'Structural Collapse', 'lat': 40.7484, 'lng': -73.9857, 'type': 'Structural'},
    ];

    // 2. Mock Rescue Team Tracking (Blue Markers - Admin Side Only)
    final rescueTeams = [
      {'id': 'team_alpha', 'name': 'Alpha Medical Unit', 'lat': 40.7306, 'lng': -73.9352, 'status': 'Responding'},
      {'id': 'team_bravo', 'name': 'Bravo Search & Rescue', 'lat': 40.7220, 'lng': -73.9970, 'status': 'On Break'},
    ];

    setState(() {
      _markers.clear();

      // Add Disaster Markers
      for (var report in disasterReports) {
        _markers.add(
          Marker(
            markerId: MarkerId(report['id'] as String),
            position: LatLng(report['lat'] as double, report['lng'] as double),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: report['title'] as String,
              snippet: 'Type: ${report['type']}',
            ),
          ),
        );
      }

      // Add Rescue Team Markers (Exclusive to Admin Dashboard)
      for (var team in rescueTeams) {
        _markers.add(
          Marker(
            markerId: MarkerId(team['id'] as String),
            position: LatLng(team['lat'] as double, team['lng'] as double),
            // Distinguish rescue teams with an Azure/Blue hue pin
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(
              title: team['name'] as String,
              snippet: 'Status: ${team['status']}',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The Live Google Map Window
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(40.7128, -74.0060), // New York
              zoom: 10,
            ),
          ),

          // Floating Dashboard Map HUD Controls
          Positioned(
            top: 25,
            left: 25,
            child: Card(
              color: Colors.white.withOpacity(0.95),
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16),
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Tactical Command Map",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Live monitoring of threats & field assets",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const Divider(height: 20),
                    _buildLegendRow(Colors.red, "Active Disaster Report"),
                    const SizedBox(height: 8),
                    _buildLegendRow(Colors.blue, "Rescue Team Deployment"),
                    const Divider(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadLiveMapData,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text("Refresh Active Feeds"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}