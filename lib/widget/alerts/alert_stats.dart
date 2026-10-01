import 'package:flutter/material.dart';

import '../../model/alert_model.dart';

class AlertStats extends StatelessWidget {
  final List<AlertModel> alerts;

  const AlertStats({
    super.key,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    final totalAlerts = alerts.length;

    final sentAlerts = alerts
        .where((e) => e.status.toLowerCase() == "sent")
        .length;

    final pendingAlerts = alerts
        .where((e) => e.status.toLowerCase() == "pending")
        .length;

    final criticalAlerts = alerts
        .where((e) => e.priority.toLowerCase() == "critical")
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 20.0;

        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 550
            ? 2
            : 1;

        final cardWidth = (constraints.maxWidth -
            (spacing * (columns - 1))) /
            columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _StatCard(
              width: cardWidth,
              title: "Total Alerts",
              value: totalAlerts.toString(),
              icon: Icons.notifications_active,
              color: Colors.blue,
            ),
            _StatCard(
              width: cardWidth,
              title: "Sent",
              value: sentAlerts.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            _StatCard(
              width: cardWidth,
              title: "Pending",
              value: pendingAlerts.toString(),
              icon: Icons.schedule,
              color: Colors.orange,
            ),
            _StatCard(
              width: cardWidth,
              title: "Critical",
              value: criticalAlerts.toString(),
              icon: Icons.warning,
              color: Colors.red,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 110,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xffF7F2FA),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}