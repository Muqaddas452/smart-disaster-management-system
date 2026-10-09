import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../model/analytics_model.dart';

class DisasterTrendChart extends StatelessWidget {
  final AnalyticsModel analytics;

  const DisasterTrendChart({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
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
              "Disaster Reports Trend",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "Monthly disaster reports received",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              height: 320,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 11,
                  minY: 0,

                  maxY: analytics.monthlyReports.isEmpty
                      ? 10
                      : (analytics.monthlyReports.reduce(
                        (a, b) => a > b ? a : b,
                  ) +
                      5),

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),

                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),

                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),

                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),

                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const months = [
                            "Jan",
                            "Feb",
                            "Mar",
                            "Apr",
                            "May",
                            "Jun",
                            "Jul",
                            "Aug",
                            "Sep",
                            "Oct",
                            "Nov",
                            "Dec",
                          ];

                          if (value.toInt() >= months.length) {
                            return const SizedBox();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              months[value.toInt()],
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,

                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(.15),
                      ),

                      dotData: const FlDotData(
                        show: true,
                      ),

                      spots: List.generate(
                        analytics.monthlyReports.length,
                            (index) => FlSpot(
                          index.toDouble(),
                          analytics.monthlyReports[index],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}