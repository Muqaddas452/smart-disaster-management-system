import 'package:flutter/material.dart';
import '../model/affected_zone_model.dart';

class AffectedZoneStatistics extends StatelessWidget {
  final List<AffectedZone> affectedZones;

  const AffectedZoneStatistics({
    super.key,
    required this.affectedZones,
  });

  @override
  Widget build(BuildContext context) {
    final totalZones = affectedZones.length;

    final highRisk =
        affectedZones.where((e) => e.riskLevel == "High").length;

    final mediumRisk =
        affectedZones.where((e) => e.riskLevel == "Medium").length;

    final lowRisk =
        affectedZones.where((e) => e.riskLevel == "Low").length;

    return Row(
      children: [

        Expanded(
          child: _buildCard(
            title: "Total Zones",
            value: totalZones.toString(),
            icon: Icons.public,
            color: Colors.blue,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: _buildCard(
            title: "High Risk",
            value: highRisk.toString(),
            icon: Icons.warning,
            color: Colors.red,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: _buildCard(
            title: "Medium Risk",
            value: mediumRisk.toString(),
            icon: Icons.error_outline,
            color: Colors.orange,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: _buildCard(
            title: "Low Risk",
            value: lowRisk.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),

      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        child: Row(
          children: [

            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(.12),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),

            const SizedBox(width: 15),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),

              ],
            ),

          ],
        ),
      ),
    );
  }
}