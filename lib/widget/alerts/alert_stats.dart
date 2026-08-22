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

    final sentAlerts =
        alerts.where((e) => e.status.toLowerCase() == "sent").length;

    final pendingAlerts =
        alerts.where((e) => e.status.toLowerCase() == "pending").length;

    final criticalAlerts =
        alerts.where((e) => e.priority.toLowerCase() == "critical").length;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _StatCard(
              title: "Total Alerts",
              value: totalAlerts.toString(),
              icon: Icons.notifications_active,
              color: Colors.blue,
            ),

            _StatCard(
              title: "Sent",
              value: sentAlerts.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),

            _StatCard(
              title: "Pending",
              value: pendingAlerts.toString(),
              icon: Icons.schedule,
              color: Colors.orange,
            ),

            _StatCard(
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
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 110,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
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