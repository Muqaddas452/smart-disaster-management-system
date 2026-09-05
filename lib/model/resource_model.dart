import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceModel {
  final String id;

  final String name;

  final int quantity;

  final String unit;

  final String location;

  final DateTime createdAt;

  const ResourceModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.createdAt,
  });

  factory ResourceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ResourceModel(
      id: doc.id,

      name: data["name"] ?? "",

      quantity: (data["quantity"] as num?)?.toInt() ?? 0,

      unit: data["unit"] ?? "",

      location: data["location"] ?? "",

      createdAt: data["createdAt"] != null
          ? (data["createdAt"] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "quantity": quantity,
      "unit": unit,
      "location": location,
      "createdAt": Timestamp.fromDate(createdAt),
    };
  }
}