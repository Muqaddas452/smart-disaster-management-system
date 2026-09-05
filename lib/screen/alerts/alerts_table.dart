import 'package:flutter/material.dart';

import '../../model/alert_model.dart';
import 'alert_badge.dart';

class AlertsTable extends StatelessWidget {
  final List<AlertModel> alerts;
  final Function(AlertModel) onView;
  final Function(AlertModel) onDelete;

  const AlertsTable({
    super.key,
    required this.alerts,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
            MaterialStateProperty.all(const Color(0xffF5F5F5)),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            columns: const [
              DataColumn(label: Text("ID")),
              DataColumn(label: Text("Disaster")),
              DataColumn(label: Text("Priority")),
              DataColumn(label: Text("Area")),
              DataColumn(label: Text("Status")),
              DataColumn(label: Text("Date")),
              DataColumn(label: Text("Actions")),
            ],
            rows: alerts.map((alert) {
              return DataRow(
                cells: [
                  DataCell(Text(alert.id)),

                  DataCell(Text(alert.disaster)),

                  DataCell(
                    _priorityChip(alert.priority),
                  ),

                  DataCell(Text(alert.area)),

                  DataCell(
                    _statusChip(alert.status),
                  ),

                  DataCell(
                    Text(
                      "${alert.date.day}/${alert.date.month}/${alert.date.year}",
                    ),
                  ),

                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: "View",
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.blue,
                          ),
                          onPressed: () => onView(alert),
                        ),

                        IconButton(
                          tooltip: "Delete",
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () => onDelete(alert),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(String priority) {
    switch (priority) {
      case "Critical":
        return const AlertBadge(
          text: "Critical",
          color: Colors.red,
        );

      case "High":
        return const AlertBadge(
          text: "High",
          color: Colors.orange,
        );

      case "Medium":
        return const AlertBadge(
          text: "Medium",
          color: Colors.amber,
        );

      default:
        return const AlertBadge(
          text: "Low",
          color: Colors.green,
        );
    }
  }

  Widget _statusChip(String status) {
    switch (status) {
      case "Sent":
        return const AlertBadge(
          text: "Sent",
          color: Colors.green,
        );

      case "Pending":
        return const AlertBadge(
          text: "Pending",
          color: Colors.orange,
        );

      default:
        return const AlertBadge(
          text: "Failed",
          color: Colors.red,
        );
    }
  }
}