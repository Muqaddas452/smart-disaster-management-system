import 'package:flutter/material.dart';

class AIPredictionCard extends StatelessWidget {
  const AIPredictionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(15),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Icon(Icons.psychology,
                    color: Colors.deepPurple),

                SizedBox(width: 8),

                Text(
                  "AI Prediction",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            Divider(),

            Text(
              "Disaster : Flood",
              style: TextStyle(fontSize: 16),
            ),

            SizedBox(height: 8),

            Text(
              "Risk Level : HIGH",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 8),

            Text(
              "Confidence : 96%",
              style: TextStyle(fontSize: 16),
            ),

            SizedBox(height: 8),

            Text(
              "Updated : Just Now",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}