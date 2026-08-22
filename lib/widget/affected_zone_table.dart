import 'package:flutter/material.dart';

import '../model/affected_zone_model.dart';
import '../services/affected_zone_service.dart';
import 'affected_zone_dialog.dart';
import 'affected_zone_form_dialog.dart';

class AffectedZoneTable extends StatelessWidget {
  final List<AffectedZone> affectedZones;

  const AffectedZoneTable({
    super.key,
    required this.affectedZones,
  });

  @override
  Widget build(BuildContext context) {
    final service = AffectedZoneService();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 25,
          headingRowColor:
          WidgetStateProperty.all(Colors.grey.shade200),

          columns: const [
            DataColumn(label: Text("Zone")),
            DataColumn(label: Text("City")),
            DataColumn(label: Text("Disaster")),
            DataColumn(label: Text("Risk")),
            DataColumn(label: Text("Population")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("Action")),
          ],

          rows: affectedZones.map((zone) {
            return DataRow(
              cells: [
                DataCell(
                  Text(zone.zoneName),
                ),

                DataCell(
                  Text(zone.city),
                ),

                DataCell(
                  Text(zone.disasterType),
                ),

                DataCell(
                  Chip(
                    backgroundColor:
                    _riskColor(zone.riskLevel),
                    label: Text(
                      zone.riskLevel,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                DataCell(
                  Text(
                    zone.population.toString(),
                  ),
                ),

                DataCell(
                  Chip(
                    backgroundColor:
                    _statusColor(zone.status),
                    label: Text(
                      zone.status,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// VIEW
                      IconButton(
                        tooltip: "View",
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                AffectedZoneDialog(
                                  zone: zone,
                                ),
                          );
                        },
                      ),

                      /// EDIT
                      IconButton(
                        tooltip: "Edit",
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.orange,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                AffectedZoneFormDialog(
                                  zone: zone,
                                ),
                          );
                        },
                      ),

                      /// DELETE
                      IconButton(
                        tooltip: "Delete",
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder: (_) =>
                                AlertDialog(
                                  title: const Text(
                                    "Delete Zone",
                                  ),
                                  content: Text(
                                    "Delete '${zone.zoneName}'?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                            context,
                                            false,
                                          ),
                                      child:
                                      const Text("Cancel"),
                                    ),

                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                            context,
                                            true,
                                          ),
                                      child:
                                      const Text("Delete"),
                                    ),
                                  ],
                                ),
                          );

                          if (confirm == true) {
                            await service
                                .deleteAffectedZone(
                              zone.id,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Affected zone deleted successfully",
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case "High":
        return Colors.red;

      case "Medium":
        return Colors.orange;

      case "Low":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Active":
        return Colors.red;

      case "Monitoring":
        return Colors.orange;

      case "Safe":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }
}