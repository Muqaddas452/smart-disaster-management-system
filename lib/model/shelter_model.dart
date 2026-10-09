import 'package:cloud_firestore/cloud_firestore.dart';

class ShelterModel {
  final String id;
  final String name;
  final String city;
  final int capacity;
  final int occupied;
  final String status;
  final DateTime createdAt;
  final double latitude;
  final double longitude;

  const ShelterModel({
    required this.id,
    required this.name,
    required this.city,
    required this.capacity,
    required this.occupied,
    required this.status,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
  });

  int get available => capacity - occupied;

  factory ShelterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ShelterModel(
      id: doc.id,

      name: data["name"] ?? "",

      city: data["location"] ??
          data["city"] ??
          "",

      capacity: (data["capacity"] as num?)?.toInt() ?? 0,

      occupied: (data["occupied"] as num?)?.toInt() ?? 0,

      status: data["status"] ??
          (((data["occupied"] ?? 0) >=
              (data["capacity"] ?? 0))
              ? "Full"
              : "Open"),
      latitude:
      (data["lat"] as num?)?.toDouble() ?? 0,

      longitude:
      (data["lng"] as num?)?.toDouble() ?? 0,

      createdAt: data["createdAt"] != null
          ? (data["createdAt"] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "location": city,
      "capacity": capacity,
      "occupied": occupied,
      "status": status,
      "createdAt": Timestamp.fromDate(createdAt),
      "lat": latitude,
      "lng": longitude,
    };
  }
}