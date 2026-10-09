import 'package:flutter/material.dart';

import '../model/affected_zone_model.dart';
import '../widget/map/google_map_widget.dart';

class AffectedZoneDialog extends StatelessWidget {
  final AffectedZone zone;

  const AffectedZoneDialog({
    super.key,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Affected Zone Details",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),

      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            _row("Zone", zone.zoneName),

            _row("City", zone.city),

            _row("Disaster", zone.disasterType),

            _row("Risk", zone.riskLevel),

            _row("Population", zone.population.toString()),

            _row("Status", zone.status),

            _row("Coordinates", zone.coordinates),

            _row("Prediction Time", zone.predictionTime),

          ],
        ),
      ),

      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.map),
          label: const Text("View on Map"),
          onPressed: () {

            Navigator.pop(context);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: Text(zone.zoneName),
                  ),
                  body: GoogleMapWidget(
                    focusLatitude: zone.latitude,
                    focusLongitude: zone.longitude,
                    focusTitle: zone.zoneName,
                  ),
                ),
              ),
            );

          },
        ),

        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Close"),
        ),

      ],
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [

          Text(
            "$title :",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),

        ],
      ),
    );
  }
}