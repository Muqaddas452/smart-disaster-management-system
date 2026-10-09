import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../model/analytics_model.dart';

class DisasterDistributionChart extends StatelessWidget {
  final AnalyticsModel analytics;

  const DisasterDistributionChart({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final data = analytics.disasterDistribution;

    final total = data.values.fold<int>(0, (a, b) => a + b);

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
    ];

    final entries = data.entries.toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Disaster Distribution",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "Distribution of reported disaster types",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              height: 320,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 55,
                        sectionsSpace: 3,
                        sections: List.generate(
                          entries.length,
                              (index) {
                            final percent = total == 0
                                ? 0.0
                                : (entries[index].value / total) * 100;

                            return PieChartSectionData(
                              color: colors[index % colors.length],
                              value: entries[index].value.toDouble(),
                              title: "${percent.toStringAsFixed(0)}%",
                              radius: 85,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 30),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        entries.length,
                            (index) {
                          final percent = total == 0
                              ? 0.0
                              : (entries[index].value / total) * 100;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: _LegendItem(
                              color: colors[index % colors.length],
                              title: entries[index].key,
                              value:
                              "${percent.toStringAsFixed(0)}%",
                            ),
                          );
                        },
                      ),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _LegendItem({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}