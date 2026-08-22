import 'package:flutter/material.dart';

enum FacilityType { shelter, hospital }

class ShelterResource {
  final String id;
  final String name;
  final FacilityType type;
  final String location;
  final int capacity;
  final int occupied;
  final double lat;
  final double lng;

  const ShelterResource({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.capacity,
    required this.occupied,
    required this.lat,
    required this.lng,
  });

  double get occupancyRate => occupied / capacity;

  Color get occupancyColor {
    if (occupancyRate < 0.6) return const Color(0xFF388E3C);
    if (occupancyRate < 0.85) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
  }
}
