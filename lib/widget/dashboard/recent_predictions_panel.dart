import 'package:flutter/material.dart';

import '../../model/affected_zone_model.dart';
import '../../services/affected_zone_service.dart';

class RecentPredictionsPanel extends StatelessWidget {
  RecentPredictionsPanel({super.key});

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
              "Recent AI Predictions",
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
                  children: predictions.map((zone) {

                    IconData icon = Icons.warning;

                    Color color = Colors.blue;

                    switch (zone.disasterType.toLowerCase()) {

                      case "flood":
                        icon = Icons.flood;
                        color = Colors.blue;
                        break;

                      case "heatwave":
                        icon = Icons.wb_sunny;
                        color = Colors.orange;
                        break;

                      case "storm":
                        icon = Icons.air;
                        color = Colors.green;
                        break;

                      case "earthquake":
                        icon = Icons.public;
                        color = Colors.red;
                        break;

                      default:
                        icon = Icons.warning;
                        color = Colors.grey;
                    }

                    return Column(
                      children: [

                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color,
                            child: Icon(
                              icon,
                              color: Colors.white,
                            ),
                          ),

                          title: Text(
                            "${zone.disasterType} Prediction",
                          ),

                          subtitle: Text(zone.city),

                          trailing: Text(zone.riskLevel),
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