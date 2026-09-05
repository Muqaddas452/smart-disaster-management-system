import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String disaster;
  final String priority;
  final String area;
  final String status;
  final String message;
  final DateTime date;
  final String createdBy;
  final int affectedUsers;
  final int readCount;

  AlertModel({
    required this.id,
    required this.disaster,
    required this.priority,
    required this.area,
    required this.status,
    required this.message,
    required this.date,
    required this.createdBy,
    required this.affectedUsers,
    required this.readCount,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AlertModel(
      id: doc.id,
      disaster: data["disasterType"] ?? "",
      priority: data["priority"] ?? "",
      area: data["targetArea"] ?? "",
      status: data["status"] ?? "Sent",
      message: data["message"] ?? "",
      date: (data["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data["createdBy"] ?? "Admin",
      affectedUsers: data["affectedUsers"] ?? 0,
      readCount: data["readCount"] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "disasterType": disaster,
      "priority": priority,
      "targetArea": area,
      "status": status,
      "message": message,
      "createdAt": Timestamp.fromDate(date),
      "createdBy": createdBy,
      "affectedUsers": affectedUsers,
      "readCount": readCount,
    };
  }
}