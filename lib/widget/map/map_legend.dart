import 'package:flutter/material.dart';

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  Widget buildItem(Color color, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color,
            child: Icon(
              icon,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Map Legend",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const Divider(),

            buildItem(Colors.blue, Icons.water_drop, "Flood"),

            buildItem(Colors.orange, Icons.public, "Earthquake"),

            buildItem(Colors.red, Icons.local_fire_department, "Heatwave"),

            buildItem(Colors.grey, Icons.thunderstorm, "Storm"),

            buildItem(Colors.green, Icons.local_shipping, "Rescue Team"),

            buildItem(Colors.purple, Icons.home, "Shelter"),

          ],
        ),
      ),
    );
  }
}