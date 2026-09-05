import 'package:flutter/material.dart';

import '../../model/affected_zone_model.dart';
import '../../services/affected_zone_service.dart';

class AIConfidencePanel extends StatelessWidget {
  AIConfidencePanel({super.key});

  final AffectedZoneService _zoneService = AffectedZoneService();

  Widget confidenceTile(
      String disaster,
      int confidence,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Text(
                disaster,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Text(
                "$confidence%",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),

            ],
          ),

          const SizedBox(height: 8),

          LinearProgressIndicator(
            value: confidence / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
            color: color,
            backgroundColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "AI Confidence",
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
                  return const Text("Unable to load confidence data.");
                }

                final zones = snapshot.data ?? [];

                if (zones.isEmpty) {
                  return const Text("No AI confidence available.");
                }

                return Column(
                  children: zones.take(5).map((zone) {

                    int confidence;
                    Color color;

                    switch (zone.riskLevel.toLowerCase()) {

                      case "critical":
                        confidence = 98;
                        color = Colors.purple;
                        break;

                      case "high":
                        confidence = 92;
                        color = Colors.red;
                        break;

                      case "medium":
                        confidence = 80;
                        color = Colors.orange;
                        break;

                      case "low":
                        confidence = 65;
                        color = Colors.green;
                        break;

                      default:
                        confidence = 50;
                        color = Colors.blueGrey;
                    }

                    return confidenceTile(
                      zone.disasterType,
                      confidence,
                      color,
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