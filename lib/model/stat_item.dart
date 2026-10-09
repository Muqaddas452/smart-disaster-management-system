import 'package:flutter/material.dart';

enum TrendDirection { up, down, flat }

class StatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trendLabel;
  final TrendDirection trend;

  const StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trendLabel,
    required this.trend,
  });
}
