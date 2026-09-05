import 'package:flutter/material.dart';

enum DisasterSeverity { low, medium, high, critical }

extension DisasterSeverityX on DisasterSeverity {
  String get label => name[0].toUpperCase() + name.substring(1);
  Color get color {
    switch (this) {
      case DisasterSeverity.low:      return const Color(0xFF43A047);
      case DisasterSeverity.medium:   return const Color(0xFFFFA000);
      case DisasterSeverity.high:     return const Color(0xFFF4511E);
      case DisasterSeverity.critical: return const Color(0xFFB71C1C);
    }
  }
}

enum DisasterStatus { reported, verifying, inProgress, contained, resolved }

extension DisasterStatusX on DisasterStatus {
  String get label {
    switch (this) {
      case DisasterStatus.reported:   return 'Reported';
      case DisasterStatus.verifying:  return 'Verifying';
      case DisasterStatus.inProgress: return 'In Progress';
      case DisasterStatus.contained:  return 'Contained';
      case DisasterStatus.resolved:   return 'Resolved';
    }
  }
  Color get color {
    switch (this) {
      case DisasterStatus.reported:   return const Color(0xFF1976D2);
      case DisasterStatus.verifying:  return const Color(0xFFF57C00);
      case DisasterStatus.inProgress: return const Color(0xFFD32F2F);
      case DisasterStatus.contained:  return const Color(0xFF7B1FA2);
      case DisasterStatus.resolved:   return const Color(0xFF388E3C);
    }
  }
}

class DisasterReport {
  final String id;
  final String type;
  final IconData icon;
  final String location;
  final DisasterSeverity severity;
  final DisasterStatus status;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final String reportedBy;
  final int affectedPopulation;

  const DisasterReport({
    required this.id,
    required this.type,
    required this.icon,
    required this.location,
    required this.severity,
    required this.status,
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.reportedBy,
    required this.affectedPopulation,
  });
}
