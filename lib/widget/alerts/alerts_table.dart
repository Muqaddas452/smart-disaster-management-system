import 'package:flutter/material.dart';
import '../../model/alert_model.dart';

class AlertsTable extends StatefulWidget {
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
  State<AlertsTable> createState() => _AlertsTableState();
}

class _AlertsTableState extends State<AlertsTable> {
  // Explicit ScrollControllers so the vertical list gets its
  // own scroll region on Flutter Web instead of the mouse
  // wheel being captured by the page's outer scroll view.
  final ScrollController _verticalController =
  ScrollController();

  final ScrollController _horizontalController =
  ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldScroll = widget.alerts.length > 5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),

        // Vertical scroll for 10+ records
        child: SizedBox(
          height: shouldScroll ? 440 : null,
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: shouldScroll,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,

              // Horizontal scroll for wide table
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) {
                  return notification.depth == 0;
                },
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,

                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all(
                      const Color(0xffE3EAF3),
                    ),

                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),

                    columnSpacing: 25,

                    columns: const [
                      DataColumn(label: Text("ID")),
                      DataColumn(label: Text("Disaster")),
                      DataColumn(label: Text("Priority")),
                      DataColumn(label: Text("Area")),
                      DataColumn(label: Text("Status")),
                      DataColumn(label: Text("Date")),
                      DataColumn(label: Text("Actions")),
                    ],

                    rows: widget.alerts
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key;
                      final alert = entry.value;

                      return DataRow(
                        color:
                        MaterialStateProperty.all(
                          index.isEven
                              ? const Color(
                            0xffF4F7FA,
                          )
                              : Colors.white,
                        ),
                        cells: [
                          DataCell(
                            Text(alert.id),
                          ),

                          DataCell(
                            Text(alert.disaster),
                          ),

                          DataCell(
                            _priorityChip(
                              alert.priority,
                            ),
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
                              mainAxisSize:
                              MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: "View",
                                  icon: const Icon(
                                    Icons.visibility,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      widget.onView(
                                        alert,
                                      ),
                                ),

                                IconButton(
                                  tooltip: "Edit",
                                  icon: const Icon(
                                    Icons.edit,
                                    color:
                                    Colors.orange,
                                  ),
                                  onPressed: () =>
                                      widget.onEdit(
                                        alert,
                                      ),
                                ),

                                IconButton(
                                  tooltip: "Delete",
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      widget.onDelete(
                                        alert,
                                      ),
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
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(String priority) {
    Color color;

    switch (priority.toLowerCase()) {
      // Most severe
      case "critical":
      case "extreme":
      case "severe":
        color = Colors.red;
        break;

      case "high":
        color = Colors.deepOrange;
        break;

      case "medium":
      case "moderate":
        color = Colors.amber.shade800;
        break;

      case "low":
      case "minor":
        color = Colors.green;
        break;

      default:
        // Unknown value - grey instead of green so it
        // doesn't silently look "safe" like a Low alert.
        color = Colors.grey;
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
      case "resolved":
      case "inactive":
        color = Colors.green;
        break;

      case "pending":
        color = Colors.orange;
        break;

      case "active":
        color = Colors.red;
        break;

      default:
        color = Colors.grey;
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
