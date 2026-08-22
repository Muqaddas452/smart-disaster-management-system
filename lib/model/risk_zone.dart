import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, critical }

extension RiskLevelX on RiskLevel {
  String get label => name[0].toUpperCase() + name.substring(1);
  Color get color {
    switch (this) {
      case RiskLevel.low:      return const Color(0xFF43A047);
      case RiskLevel.medium:   return const Color(0xFFFFA000);
      case RiskLevel.high:     return const Color(0xFFF4511E);
      case RiskLevel.critical: return const Color(0xFFB71C1C);
    }
  }
}

class RiskZone {
  final String id;
  final String name;
  final RiskLevel level;
  final List<Offset> polygonPoints; // normalized 0..1
  final double lat;
  final double lng;

  const RiskZone({
    required this.id,
    required this.name,
    required this.level,
    required this.polygonPoints,
    required this.lat,
    required this.lng,
  });
}
