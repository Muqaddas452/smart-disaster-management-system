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
    // Total number of affected zones
    final totalZones = affectedZones.length;

    // HIGH RISK:
    // Count both "High" and "Extreme"
    final highRisk = affectedZones.where((e) {
      final risk = e.riskLevel.trim().toLowerCase();

      return risk == "high" || risk == "extreme";
    }).length;

    // MEDIUM RISK:
    // Count both "Medium" and "Moderate"
    final mediumRisk = affectedZones.where((e) {
      final risk = e.riskLevel.trim().toLowerCase();

      return risk == "medium" || risk == "moderate";
    }).length;

    // LOW RISK:
    // Count only "Low"
    final lowRisk = affectedZones.where((e) {
      final risk = e.riskLevel.trim().toLowerCase();

      return risk == "low";
    }).length;

    return Row(
      children: [
        // ==========================================
        // TOTAL ZONES
        // ==========================================
        Expanded(
          child: _buildCard(
            title: "Total Zones",
            value: totalZones.toString(),
            icon: Icons.public,
            color: Colors.blue,
          ),
        ),

        const SizedBox(width: 15),

        // ==========================================
        // HIGH RISK
        // High + Extreme
        // ==========================================
        Expanded(
          child: _buildCard(
            title: "High Risk",
            value: highRisk.toString(),
            icon: Icons.warning,
            color: Colors.red,
          ),
        ),

        const SizedBox(width: 15),

        // ==========================================
        // MEDIUM RISK
        // Medium + Moderate
        // ==========================================
        Expanded(
          child: _buildCard(
            title: "Medium Risk",
            value: mediumRisk.toString(),
            icon: Icons.error_outline,
            color: Colors.orange,
          ),
        ),

        const SizedBox(width: 15),

        // ==========================================
        // LOW RISK
        // Low only
        // ==========================================
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

  // ==========================================
  // STATISTICS CARD
  // ==========================================

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
            // Icon
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

            // Number + title
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