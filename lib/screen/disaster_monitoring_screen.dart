import 'package:flutter/material.dart';

import '../widget/dashboard/ai_prediction_panel.dart';
import '../widget/dashboard/current_weather_panel.dart';
import '../widget/dashboard/active_disaster_panel.dart';
import '../widget/dashboard/ai_confidence_panel.dart';
import '../widget/dashboard/emergency_actions_panel.dart';

class DisasterMonitoringScreen extends StatelessWidget {
  const DisasterMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AIPredictionPanel(),

          const SizedBox(height: 20),

          const CurrentWeatherPanel(),

          const SizedBox(height: 20),

          ActiveDisasterPanel(),

          const SizedBox(height: 20),

          AIConfidencePanel(),

          const SizedBox(height: 20),

          const EmergencyActionsPanel(),

        ],
      ),
    );
  }
}