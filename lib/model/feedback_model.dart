import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String name;
  final String email;
  final String message;
  final int rating;
  final String status;
  final DateTime timestamp;

  const FeedbackModel({
    required this.id,
    required this.name,
    required this.email,
    required this.message,
    required this.rating,
    required this.status,
    required this.timestamp,
  });

  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FeedbackModel(
      id: doc.id,

      name: data["name"] ?? "Anonymous",

      email: data["email"] ?? "",

      message: data["message"] ?? "",

      rating: (data["rating"] ?? 0).toInt(),

      status: data["status"] ?? "New",

      timestamp: data["timestamp"] != null
          ? (data["timestamp"] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  String get formattedDate {
    return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
  }

  String get formattedTime {
    return "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";
  }
}