import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

import '../../model/report_model.dart';
import '../../services/report_service.dart';
import '../../model/rescue_team_model.dart';
import '../../services/rescue_team_service.dart';
import '../common/glass_card.dart';
import '../common/section_header.dart';

class AnalyticsPanel extends StatelessWidget {
  const AnalyticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = Responsive.isCompact(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics & Trends',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 14),

        compact
            ? const Column(
          children: [
            _TrendCard(),
            SizedBox(height: 12),
            _ResponseTimeCard(),
            SizedBox(height: 12),
            _BreakdownCard(),
          ],
        )
            : const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _TrendCard(),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: _ResponseTimeCard(),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _BreakdownCard(),
            ),
          ],
        ),
      ],
    );
  }
}
class _TrendCard extends StatelessWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: ReportService().getReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 260,
              child: Center(
                child: Text(
                  "Failed to load analytics",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final reports = snapshot.data ?? [];

        final List<double> monthlyData =
        List<double>.filled(12, 0);

        for (final report in reports) {
          final month = report.reportedAt.month;
          monthlyData[month - 1]++;
        }

        final List<FlSpot> spots = List.generate(
          12,
              (index) => FlSpot(
            index.toDouble(),
            monthlyData[index],
          ),
        );

        const labels = [
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

        return GlassCard(
          hoverable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.trending_up_rounded,
                title: "Disaster Trend",
                subtitle: "Monthly reports from Firebase",
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    borderData:
                    FlBorderData(show: false),

                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.border,
                          strokeWidth: 1,
                        );
                      },
                    ),

                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles:
                        SideTitles(showTitles: false),
                      ),

                      rightTitles: const AxisTitles(
                        sideTitles:
                        SideTitles(showTitles: false),
                      ),

                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color:
                                AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),

                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();

                            if (index < 0 || index > 11) {
                              return const SizedBox();
                            }

                            return Text(
                              labels[index],
                              style: const TextStyle(
                                fontSize: 9,
                                color:
                                AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData:
                        const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary
                              .withAlpha(30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _ResponseTimeCard extends StatelessWidget {
  const _ResponseTimeCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RescueTeam>>(
      stream: RescueTeamService().getRescueTeams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final teams = snapshot.data ?? [];
        final List<double> data = List.filled(12, 0);
        final List<int> count = List.filled(12, 0);

        for (final team in teams) {
          if (team.dispatchTime != null &&
              team.arrivalTime != null) {

            final month = team.dispatchTime!.month - 1;

            final minutes = team.arrivalTime!
                .difference(team.dispatchTime!)
                .inMinutes;

            data[month] += minutes;
            count[month]++;
          }
        }

        for (int i = 0; i < 12; i++) {
          if (count[i] > 0) {
            data[i] /= count[i];
          }
        }

        const labels = [
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

        return GlassCard(
          hoverable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.timer_rounded,
                title: "Avg Response Time",
                subtitle: "Live Firebase Data",
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),

                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.border,
                          strokeWidth: 1,
                        );
                      },
                    ),

                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),

                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),

                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),

                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();

                            if (index < 0 || index >= labels.length) {
                              return const SizedBox();
                            }

                            return Text(
                              labels[index],
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    barGroups: List.generate(
                      data.length,
                          (i) => BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data[i],
                            color: AppColors.secondary,
                            width: 10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard();

  static const List<Color> _pieColors = [
    AppColors.primary,
    AppColors.info,
    AppColors.warning,
    AppColors.danger,
    Color(0xFF7B1FA2),
    Colors.teal,
    Colors.brown,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: ReportService().getReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 320,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 320,
              child: Center(
                child: Text("Failed to load data"),
              ),
            ),
          );
        }

        final reports = snapshot.data ?? [];

        final Map<String, int> disasterCount = {};

        for (final report in reports) {
          final type = report.emergencyType.trim();

          disasterCount[type] = (disasterCount[type] ?? 0) + 1;
        }

        final totalReports =
        disasterCount.values.fold(0, (a, b) => a + b);

        final keys = disasterCount.keys.toList();

        final sections = List.generate(
          keys.length,
              (index) {
            final count = disasterCount[keys[index]]!;

            return PieChartSectionData(
              value: count.toDouble(),
              title: totalReports == 0
                  ? "0%"
                  : "${((count / totalReports) * 100).round()}%",
              radius: 55,
              color: _pieColors[index % _pieColors.length],
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        );

        return GlassCard(
          hoverable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                icon: Icons.pie_chart_rounded,
                title: "Disaster Types",
                subtitle: "Live Firebase Reports",
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 170,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 28,
                    sectionsSpace: 2,
                    sections: sections,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ...List.generate(
                keys.length,
                    (index) {
                  final count = disasterCount[keys[index]]!;

                  final percent = totalReports == 0
                      ? 0
                      : ((count / totalReports) * 100).round();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _pieColors[index % _pieColors.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            keys[index],
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        Text(
                          "$count",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          "$percent%",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}