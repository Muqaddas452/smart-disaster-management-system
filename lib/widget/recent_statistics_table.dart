import 'package:flutter/material.dart';

import '../model/analytics_model.dart';

class RecentStatisticsTable extends StatelessWidget {
  final AnalyticsModel analytics;

  const RecentStatisticsTable({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final data = analytics.disasterDistribution.entries.toList();

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
              "Recent Disaster Statistics",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "Summary of recent disaster activities",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                MaterialStateProperty.all(
                  Colors.grey.shade100,
                ),

                columnSpacing: 40,
                horizontalMargin: 16,

                columns: const [
                  DataColumn(
                    label: Text(
                      "Disaster",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  DataColumn(
                    label: Text(
                      "Reports",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  DataColumn(
                    label: Text(
                      "Rescued",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  DataColumn(
                    label: Text(
                      "AI Accuracy",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  DataColumn(
                    label: Text(
                      "Status",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                rows: data.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          item.key,
                          style: const TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),

                      DataCell(
                        Text(
                          item.value.toString(),
                        ),
                      ),

                      DataCell(
                        Text(
                          analytics.rescuedPeople
                              .toString(),
                        ),
                      ),

                      DataCell(
                        Text(
                          "${analytics.aiAccuracy.toStringAsFixed(1)}%",
                        ),
                      ),

                      DataCell(
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                            Colors.green.shade100,
                            borderRadius:
                            BorderRadius.circular(
                                20),
                          ),
                          child: const Text(
                            "Completed",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}