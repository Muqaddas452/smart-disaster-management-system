import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a rescue team.
///
/// Used by:
/// - User App
/// - Admin Dashboard
/// - Google Maps
/// - Firebase Firestore
class RescueTeamModel {
  /// Firestore document ID
  final String id;

  /// Team name
  ///
  /// Example:
  /// Rescue 1122 Team A
  final String name;

  /// Vehicle type
  ///
  /// Example:
  /// Ambulance
  /// Fire Truck
  /// Rescue Van
  final String vehicle;

  /// Contact number
  final String phone;

  /// Team current location
  final LatLng location;

  /// Team status
  ///
  /// Available
  /// Assigned
  /// En Route
  /// Rescuing
  /// Offline
  final String status;

  /// Assigned disaster zone
  ///
  /// Firestore document ID
  final String assignedZone;

  /// Last updated time
  final DateTime updatedAt;

  RescueTeamModel({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.phone,
    required this.location,
    required this.status,
    required this.assignedZone,
    required this.updatedAt,
  });

  /// Create model from Firestore
  factory RescueTeamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RescueTeamModel(
      id: doc.id,

      name: data['name'] ?? '',

      vehicle: data['vehicle'] ?? '',

      phone: data['phone'] ?? '',

      location: LatLng(
        (data['latitude'] as num?)?.toDouble() ?? 0.0,
        (data['longitude'] as num?)?.toDouble() ?? 0.0,
      ),

      status: data['status'] ?? 'Available',

      assignedZone: data['assignedZone'] ?? '',

      updatedAt:
      (data['updatedAt'] as Timestamp?)
          ?.toDate() ??
          DateTime.now(),
    );
  }

  /// Convert model to Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,

      'vehicle': vehicle,

      'phone': phone,

      'latitude': location.latitude,

      'longitude': location.longitude,

      'status': status,

      'assignedZone': assignedZone,

      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create modified copy
  RescueTeamModel copyWith({
    String? id,
    String? name,
    String? vehicle,
    String? phone,
    LatLng? location,
    String? status,
    String? assignedZone,
    DateTime? updatedAt,
  }) {
    return RescueTeamModel(
      id: id ?? this.id,
      name: name ?? this.name,
      vehicle: vehicle ?? this.vehicle,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      status: status ?? this.status,
      assignedZone: assignedZone ?? this.assignedZone,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper properties
  bool get isAvailable =>
      status.toLowerCase() == 'available';

  bool get isAssigned =>
      status.toLowerCase() == 'assigned';

  bool get isEnRoute =>
      status.toLowerCase() == 'en route';

  bool get isRescuing =>
      status.toLowerCase() == 'rescuing';

  bool get isOffline =>
      status.toLowerCase() == 'offline';

  @override
  String toString() {
    return '''
RescueTeamModel(
id: $id,
name: $name,
vehicle: $vehicle,
status: $status,
assignedZone: $assignedZone,
latitude: ${location.latitude},
longitude: ${location.longitude}
)
''';
  }
}