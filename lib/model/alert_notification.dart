import 'package:flutter/material.dart';

enum AlertLevel { info, warning, critical }

extension AlertLevelX on AlertLevel {
  Color get color {
    switch (this) {
      case AlertLevel.info:     return const Color(0xFF1976D2);
      case AlertLevel.warning:  return const Color(0xFFF57C00);
      case AlertLevel.critical: return const Color(0xFFD32F2F);
    }
  }
  IconData get icon {
    switch (this) {
      case AlertLevel.info:     return Icons.info_outline_rounded;
      case AlertLevel.warning:  return Icons.warning_amber_rounded;
      case AlertLevel.critical: return Icons.crisis_alert_rounded;
    }
  }
}

class AlertNotification {
  final String id;
  final String title;
  final String message;
  final AlertLevel level;
  final DateTime timestamp;

  const AlertNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.level,
    required this.timestamp,
  });
}
