import 'package:flutter/material.dart';

import '../../widgets/map/disaster_map.dart';

class DisasterMapScreen extends StatelessWidget {
  const DisasterMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Disaster Map',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,

        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "Map Legend",
            onPressed: () {
              _showLegend(context);
            },
          ),
        ],
      ),

      body: const DisasterMap(
        isAdmin: false,
      ),
    );
  }

  //----------------------------------------------------------
  // Map Legend Dialog
  //----------------------------------------------------------

  void _showLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Map Legend"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              _legendTile(
                Colors.red,
                "Affected Area",
              ),

              const SizedBox(height: 10),

              _legendTile(
                Colors.green,
                "Safe Zone",
              ),

              const SizedBox(height: 10),

              _legendTile(
                Colors.orange,
                "Moderate Risk",
              ),

              const SizedBox(height: 10),

              _legendTile(
                Colors.blue,
                "Your Location",
              ),

              const SizedBox(height: 10),

              _legendTile(
                Colors.purple,
                "Rescue Team",
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  //----------------------------------------------------------
  // Legend Row
  //----------------------------------------------------------

  Widget _legendTile(
      Color color,
      String text,
      ) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}