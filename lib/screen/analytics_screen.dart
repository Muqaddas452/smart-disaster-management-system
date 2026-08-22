import 'package:flutter/material.dart';

import '../model/analytics_model.dart';
import '../services/analytics_service.dart';

import '../widget/analytics_summary_cards.dart';
import '../widget/disaster_distribution_chart.dart';
import '../widget/disaster_trend_chart.dart';
import '../widget/recent_statistics_table.dart';

class AnalyticsScreen extends StatelessWidget {
  AnalyticsScreen({super.key});

  final AnalyticsService _service = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AnalyticsModel>(
      stream: _service.getAnalytics(),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text("No Analytics Data"),
            );
          }

          final analytics = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                AnalyticsSummaryCards(
                  analytics: analytics,
                ),

                const SizedBox(height: 25),

                DisasterTrendChart(
                  analytics: analytics,
                ),

                const SizedBox(height: 25),

                DisasterDistributionChart(
                  analytics: analytics,
                ),

                const SizedBox(height: 25),

                RecentStatisticsTable(
                  analytics: analytics,
                ),
              ],
            ),
          );
        }
    );
  }
}