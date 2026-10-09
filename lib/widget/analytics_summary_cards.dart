import 'package:flutter/material.dart';

import '../model/analytics_model.dart';

class AnalyticsSummaryCards extends StatelessWidget {
  final AnalyticsModel analytics;

  const AnalyticsSummaryCards({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: "Total Reports",
                      value: analytics.totalReports.toString(),
                      subtitle: "Live from Firebase",
                      icon: Icons.report_problem_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: "Active Disasters",
                      value: analytics.activeDisasters.toString(),
                      subtitle: "Current Alerts",
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: "People Rescued",
                      value: analytics.rescuedPeople.toString(),
                      subtitle: "Rescue Teams",
                      icon: Icons.volunteer_activism_outlined,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: "AI Accuracy",
                      value: "${analytics.aiAccuracy.toStringAsFixed(1)}%",
                      subtitle: "Prediction Success",
                      icon: Icons.auto_graph,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: "Total Reports",
                value: analytics.totalReports.toString(),
                subtitle: "Live from Firebase",
                icon: Icons.report_problem_outlined,
                color: Colors.blue,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: _SummaryCard(
                title: "Active Disasters",
                value: analytics.activeDisasters.toString(),
                subtitle: "Current Alerts",
                icon: Icons.warning_amber_rounded,
                color: Colors.red,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: _SummaryCard(
                title: "People Rescued",
                value: analytics.rescuedPeople.toString(),
                subtitle: "Rescue Teams",
                icon: Icons.volunteer_activism_outlined,
                color: Colors.green,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: _SummaryCard(
                title: "AI Accuracy",
                value: "${analytics.aiAccuracy.toStringAsFixed(1)}%",
                subtitle: "Prediction Success",
                icon: Icons.auto_graph,
                color: Colors.deepPurple,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}