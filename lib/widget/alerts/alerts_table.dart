import 'package:flutter/material.dart';
import '../../model/alert_model.dart';

class AlertsTable extends StatelessWidget {
  final List<AlertModel> alerts;

  final Function(AlertModel) onView;
  final Function(AlertModel) onEdit;
  final Function(AlertModel) onDelete;

  const AlertsTable({
    super.key,
    required this.alerts,
    required this.onView,
    required this.onEdit,
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

        // Vertical scroll for 10+ records
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,

          // Horizontal scroll for wide table
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,

            child: DataTable(
              headingRowColor:
              MaterialStateProperty.all(
                const Color(0xffF5F5F5),
              ),

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
                    DataCell(
                      Text(alert.id),
                    ),

                    DataCell(
                      Text(alert.disaster),
                    ),

                    DataCell(
                      _priorityChip(alert.priority),
                    ),

                    DataCell(
                      Text(alert.area),
                    ),

                    DataCell(
                      _statusChip(alert.status),
                    ),

                    DataCell(
                      Text(
                        "${alert.date.day}/"
                            "${alert.date.month}/"
                            "${alert.date.year}",
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
                            tooltip: "Edit",
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.orange,
                            ),
                            onPressed: () => onEdit(alert),
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
      ),
    );
  }

  Widget _priorityChip(String priority) {
    Color color;

    switch (priority.toLowerCase()) {
      case "critical":
        color = Colors.red;
        break;

      case "high":
        color = Colors.orange;
        break;

      case "medium":
        color = Colors.amber;
        break;

      default:
        color = Colors.green;
    }

    return Chip(
      label: Text(
        priority,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
    );
  }

  Widget _statusChip(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case "sent":
        color = Colors.green;
        break;

      case "pending":
        color = Colors.orange;
        break;

      default:
        color = Colors.red;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
    );
  }
}