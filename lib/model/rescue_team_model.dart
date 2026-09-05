import 'package:cloud_firestore/cloud_firestore.dart';

class RescueTeam {
  final String id;

  final String teamName;
  final String leader;
  final String phone;
  final int members;
  final String vehicle;

  final String status;

  final String assignedReportId;
  final String assignedArea;

  final double latitude;
  final double longitude;

  final DateTime createdAt;

  // Compatibility fields for Dashboard Analytics
  final DateTime? dispatchTime;
  final DateTime? arrivalTime;

  const RescueTeam({
    required this.id,
    required this.teamName,
    required this.leader,
    required this.phone,
    required this.members,
    required this.vehicle,
    required this.status,
    required this.assignedReportId,
    required this.assignedArea,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.dispatchTime,
    this.arrivalTime,
  });

  factory RescueTeam.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RescueTeam(
      id: doc.id,

      teamName: data["teamName"] ?? "",

      leader: data["leader"] ?? "",

      phone: data["phone"] ?? "",

      members: data["members"] is int
          ? data["members"]
          : int.tryParse(data["members"].toString()) ?? 0,

      vehicle: data["vehicle"] ?? "",

      status: data["status"] ?? "Pending",

      assignedReportId: data["assignedReportId"] ?? "",

      assignedArea: data["assignedArea"] ?? "",

      latitude: (data["latitude"] ?? 0).toDouble(),

      longitude: (data["longitude"] ?? 0).toDouble(),

      createdAt: data["createdAt"] != null
          ? (data["createdAt"] as Timestamp).toDate()
          : DateTime.now(),

      dispatchTime: data["dispatchTime"] != null
          ? (data["dispatchTime"] as Timestamp).toDate()
          : null,

      arrivalTime: data["arrivalTime"] != null
          ? (data["arrivalTime"] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "teamName": teamName,
      "leader": leader,
      "phone": phone,
      "members": members,
      "vehicle": vehicle,
      "status": status,
      "assignedReportId": assignedReportId,
      "assignedArea": assignedArea,
      "latitude": latitude,
      "longitude": longitude,
      "createdAt": Timestamp.fromDate(createdAt),

      if (dispatchTime != null)
        "dispatchTime": Timestamp.fromDate(dispatchTime!),

      if (arrivalTime != null)
        "arrivalTime": Timestamp.fromDate(arrivalTime!),
    };
  }

  RescueTeam copyWith({
    String? id,
    String? teamName,
    String? leader,
    String? phone,
    int? members,
    String? vehicle,
    String? status,
    String? assignedReportId,
    String? assignedArea,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? dispatchTime,
    DateTime? arrivalTime,
  }) {
    return RescueTeam(
      id: id ?? this.id,
      teamName: teamName ?? this.teamName,
      leader: leader ?? this.leader,
      phone: phone ?? this.phone,
      members: members ?? this.members,
      vehicle: vehicle ?? this.vehicle,
      status: status ?? this.status,
      assignedReportId: assignedReportId ?? this.assignedReportId,
      assignedArea: assignedArea ?? this.assignedArea,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      dispatchTime: dispatchTime ?? this.dispatchTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
    );
  }
}