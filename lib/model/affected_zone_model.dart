import 'package:cloud_firestore/cloud_firestore.dart';

class AffectedZone {
  final String id;
  final String zoneName;
  final String city;
  final String disasterType;
  final String riskLevel;
  final int population;
  final String status;

  final double latitude;
  final double longitude;
  final double radius;

  final String coordinates;
  final String predictionTime;

  const AffectedZone({
    required this.id,
    required this.zoneName,
    required this.city,
    required this.disasterType,
    required this.riskLevel,
    required this.population,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.coordinates,
    required this.radius,
    required this.predictionTime,
  });

  factory AffectedZone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final double lat = (data["latitude"] as num?)?.toDouble() ?? 0.0;
    final double lng = (data["longitude"] as num?)?.toDouble() ?? 0.0;
    final double radius = (data["radius"] as num?)?.toDouble() ?? 5000;
    String prediction = "";

    if (data["createdAt"] != null &&
        data["createdAt"] is Timestamp) {
      final date = (data["createdAt"] as Timestamp).toDate();

      prediction =
      "${date.day}/${date.month}/${date.year} "
          "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }

    return AffectedZone(
      id: doc.id,

      zoneName: data["zoneName"] ?? "",

      city: data["city"] ?? "",

      disasterType: data["disasterType"] ?? "",

      riskLevel: data["riskLevel"] ?? "",

      population: (data["population"] ?? 0) is int
          ? data["population"]
          : int.tryParse(data["population"].toString()) ?? 0,

      status: data["status"] ?? "",

      latitude: lat,

      longitude: lng,

      radius: radius,

      coordinates: "$lat, $lng",

      predictionTime: prediction,
    );
  }

  /// Convert object to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      "zoneName": zoneName,
      "city": city,
      "disasterType": disasterType,
      "riskLevel": riskLevel,
      "population": population,
      "status": status,
      "latitude": latitude,
      "longitude": longitude,
      'radius': radius,
      "createdAt": FieldValue.serverTimestamp(),
    };
  }

  /// CopyWith for Update operations
  AffectedZone copyWith({
    String? id,
    String? zoneName,
    String? city,
    String? disasterType,
    String? riskLevel,
    int? population,
    String? status,
    double? latitude,
    double? longitude,
    double? radius,
    String? coordinates,
    String? predictionTime,
  }) {
    return AffectedZone(
      id: id ?? this.id,
      zoneName: zoneName ?? this.zoneName,
      city: city ?? this.city,
      disasterType: disasterType ?? this.disasterType,
      riskLevel: riskLevel ?? this.riskLevel,
      population: population ?? this.population,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      coordinates:
      coordinates ?? "${latitude ?? this.latitude}, ${longitude ?? this.longitude}",
      radius: radius ?? this.radius,
      predictionTime: predictionTime ?? this.predictionTime,
    );
  }
}