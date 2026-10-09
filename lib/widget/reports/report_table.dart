import 'package:flutter/material.dart';

import '../../model/report_model.dart';
import 'report_details_dialog.dart';
import 'report_image.dart';
import 'status_chip.dart';

class ReportTable extends StatelessWidget {
  final List<Report> reports;

  const ReportTable({
    super.key,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 30,
              headingRowColor: MaterialStateProperty.all(
                Colors.grey.shade200,
              ),
              columns: const [
                DataColumn(label: Text("Image")),
                DataColumn(label: Text("Reporter")),
                DataColumn(label: Text("Emergency")),
                DataColumn(label: Text("Phone")),
                DataColumn(label: Text("Coordinates")),
                DataColumn(label: Text("Severity")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Date")),
                DataColumn(label: Text("Action")),
              ],
              rows: reports.map((report) {
                return DataRow(
                  cells: [
                    DataCell(
                      ReportImage(
                        imageUrl: report.imageUrl,
                      ),
                    ),

                    DataCell(
                      Text(report.reporterName),
                    ),

                    DataCell(
                      Text(report.emergencyType),
                    ),

                    DataCell(
                      Text(report.phoneNumber),
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
                      StatusChip(
                        status: report.status,
                      ),
                    ),

                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.formattedDate),
                          Text(
                            report.formattedTime,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    DataCell(
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text("View"),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => ReportDetailsDialog(
                              report: report,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}