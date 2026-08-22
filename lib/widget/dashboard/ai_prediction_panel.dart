import 'package:flutter/material.dart';

import '../../model/affected_zone_model.dart';
import '../../services/affected_zone_service.dart';

class AIPredictionPanel extends StatelessWidget {
  AIPredictionPanel({super.key});

  final AffectedZoneService _zoneService = AffectedZoneService();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Live AI Predictions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            StreamBuilder<List<AffectedZone>>(
              stream: _zoneService.getAffectedZones(),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Text("Unable to load predictions.");
                }

                final predictions = snapshot.data ?? [];

                if (predictions.isEmpty) {
                  return const Text("No AI predictions available.");
                }

                return Column(
                  children: predictions.take(5).map((zone) {

                    IconData icon = Icons.warning;

                    switch (zone.disasterType.toLowerCase()) {
                      case "flood":
                        icon = Icons.flood;
                        break;

                      case "heatwave":
                        icon = Icons.wb_sunny;
                        break;

                      case "earthquake":
                        icon = Icons.public;
                        break;

                      case "storm":
                        icon = Icons.air;
                        break;

                      default:
                        icon = Icons.warning;
                    }

                    String confidence;

                    switch (zone.riskLevel.toLowerCase()) {
                      case "critical":
                        confidence = "98%";
                        break;

                      case "high":
                        confidence = "92%";
                        break;

                      case "medium":
                        confidence = "75%";
                        break;

                      default:
                        confidence = "55%";
                    }

                    return Column(
                      children: [

                        ListTile(
                          leading: Icon(icon),

                          title: Text(zone.disasterType),

                          subtitle: Text(zone.city),

                          trailing: Text(confidence),
                        ),

                        const Divider(),

                      ],
                    );

                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}