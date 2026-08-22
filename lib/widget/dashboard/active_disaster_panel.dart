import 'package:flutter/material.dart';

import '../../model/report_model.dart';
import '../../services/report_service.dart';

class ActiveDisasterPanel extends StatelessWidget {
  ActiveDisasterPanel({super.key});

  final ReportService _reportService = ReportService();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Active Disasters",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            StreamBuilder<List<Report>>(
              stream: _reportService.getReports(),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Text("Failed to load disaster reports.");
                }

                final reports = snapshot.data ?? [];

                if (reports.isEmpty) {
                  return const Text("No active disaster reports.");
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(

                    columns: const [

                      DataColumn(
                        label: Text("Disaster"),
                      ),

                      DataColumn(
                        label: Text("Location"),
                      ),

                      DataColumn(
                        label: Text("Severity"),
                      ),

                      DataColumn(
                        label: Text("Status"),
                      ),

                    ],

                    rows: reports.map((report) {

                      return DataRow(

                        cells: [

                          DataCell(
                            Text(report.emergencyType),
                          ),

                          DataCell(
                            Text(
                              "${report.latitude.toStringAsFixed(4)}, "
                                  "${report.longitude.toStringAsFixed(4)}",
                            ),
                          ),

                          DataCell(
                            Text(report.severity),
                          ),

                          DataCell(
                            Text(report.status),
                          ),

                        ],

                      );

                    }).toList(),

                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}