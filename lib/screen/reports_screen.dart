import 'package:flutter/material.dart';

import '../../model/report_model.dart';
import '../../services/report_service.dart';
import '../../widget/reports/report_statistics.dart';
import '../../widget/reports/report_table.dart';

class ReportsScreen extends StatelessWidget {
  ReportsScreen({super.key});

  final ReportService _reportService = ReportService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: StreamBuilder<List<Report>>(
          stream: _reportService.getReports(),

          builder: (context, snapshot) {

            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              );
            }

            final reports = snapshot.data ?? [];

            if (reports.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Icon(
                      Icons.assignment,
                      size: 80,
                      color: Colors.grey,
                    ),

                    SizedBox(height: 20),

                    Text(
                      "No Reports Found",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
                      "User reports will appear here automatically.",
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                const Text(
                  "User Reports",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "${reports.length} reports received from users",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 25),

                ReportStatistics(
                  reports: reports,
                ),

                const SizedBox(height: 25),

                Expanded(
                  child: ReportTable(
                    reports: reports,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}