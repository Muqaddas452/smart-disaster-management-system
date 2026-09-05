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
          WidgetStateProperty.all(
            Colors.grey.shade200,
          ),

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

                // ==========================
                // ZONE
                // ==========================
                DataCell(
                  Text(zone.zoneName),
                ),

                // ==========================
                // CITY
                // ==========================
                DataCell(
                  Text(zone.city),
                ),

                // ==========================
                // DISASTER
                // ==========================
                DataCell(
                  Text(zone.disasterType),
                ),

                // ==========================
                // RISK
                // ==========================
                DataCell(
                  Chip(
                    backgroundColor:
                    _riskColor(zone.riskLevel),
                    label: Text(
                      _displayRisk(zone.riskLevel),
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // ==========================
                // POPULATION
                // ==========================
                DataCell(
                  Text(
                    zone.population.toString(),
                  ),
                ),

                // ==========================
                // STATUS
                // ==========================
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

                // ==========================
                // ACTIONS
                // ==========================
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ======================
                      // VIEW
                      // ======================
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

                      // ======================
                      // EDIT
                      // ======================
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

                      // ======================
                      // DELETE
                      // ======================
                      IconButton(
                        tooltip: "Delete",
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () async {

                          // Show confirmation
                          final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder:
                                (dialogContext) {
                              return AlertDialog(
                                title: const Text(
                                  "Delete Zone",
                                ),

                                content: Text(
                                  "Are you sure you want to "
                                      "delete '${zone.zoneName}'?",
                                ),

                                actions: [

                                  // CANCEL
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                        false,
                                      );
                                    },
                                    child: const Text(
                                      "Cancel",
                                    ),
                                  ),

                                  // DELETE
                                  ElevatedButton(
                                    style:
                                    ElevatedButton
                                        .styleFrom(
                                      backgroundColor:
                                      Colors.red,
                                      foregroundColor:
                                      Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                        true,
                                      );
                                    },
                                    child: const Text(
                                      "Delete",
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          // User cancelled
                          if (confirm != true) {
                            return;
                          }

                          // ======================
                          // DELETE FROM FIRESTORE
                          // ======================
                          try {
                            await service
                                .deleteAffectedZone(
                              zone.id,
                            );

                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                backgroundColor:
                                Colors.green,
                                content: Text(
                                  "Affected zone deleted successfully.",
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                backgroundColor:
                                Colors.red,
                                content: Text(
                                  "Delete failed: $e",
                                ),
                              ),
                            );
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

  // ==========================
  // RISK COLOR
  // ==========================
  Color _riskColor(String risk) {
    switch (risk.trim().toLowerCase()) {
      case "high":
      case "extreme":
        return Colors.red;

      case "medium":
      case "moderate":
        return Colors.orange;

      case "low":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  String _displayRisk(String risk) {
    switch (risk.trim().toLowerCase()) {
      case "high":
      case "extreme":
        return "High";

      case "medium":
      case "moderate":
        return "Medium";

      case "low":
        return "Low";

      default:
        return risk;
    }
  }

  // ==========================
  // STATUS COLOR
  // ==========================
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