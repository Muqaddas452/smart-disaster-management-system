import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String reportId;
  final String recipientType;
  final String title;
  final String message;
  final String type;
  final bool read;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.reportId,
    required this.recipientType,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    this.createdAt,
  });

  factory NotificationModel.fromFirestore(
      DocumentSnapshot doc) {
    final data =
    doc.data() as Map<String, dynamic>;

    return NotificationModel(
      id: doc.id,
      userId: data["userId"] ?? "",
      reportId: data["reportId"] ?? "",
      recipientType: data["recipientType"] ?? "",
      title: data["title"] ?? "Notification",
      message: data["message"] ?? "",
      type: data["type"] ?? "",
      read: data["read"] ?? false,
      createdAt: data["createdAt"] is Timestamp
          ? (data["createdAt"] as Timestamp).toDate()
          : null,
    );
  }
}