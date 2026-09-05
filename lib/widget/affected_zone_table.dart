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

          // ==========================
          // TABLE HEADER COLOR
          // ==========================
          headingRowColor: WidgetStateProperty.all(
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

          // ==========================
          // TABLE ROWS
          // ==========================
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
                    backgroundColor: _riskColor(
                      zone.riskLevel,
                    ),
                    label: Text(
                      _displayRisk(
                        zone.riskLevel,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
                    backgroundColor: _statusColor(
                      zone.status,
                    ),
                    label: Text(
                      zone.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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
                            builder: (_) => AffectedZoneDialog(
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

                          // ==================================
                          // SHOW DELETE CONFIRMATION DIALOG
                          // ==================================
                          final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text(
                                  "Delete Zone",
                                ),

                                content: Text(
                                  "Are you sure you want to delete "
                                      "'${zone.zoneName}'?",
                                ),

                                actions: [

                                  // ==========================
                                  // CANCEL
                                  // ==========================
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

                                  // ==========================
                                  // DELETE
                                  // ==========================
                                  ElevatedButton(
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

                          // ==================================
                          // USER CANCELLED
                          // ==================================
                          if (confirm != true) {
                            return;
                          }

                          try {

                            // ==================================
                            // DELETE FIRESTORE DOCUMENT
                            // ==================================
                            await service.deleteAffectedZone(
                              zone.id,
                            );

                            if (!context.mounted) {
                              return;
                            }

                            // ==================================
                            // SUCCESS MESSAGE
                            // ==================================
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Affected zone deleted successfully",
                                ),
                              ),
                            );

                          } catch (e) {

                            if (!context.mounted) {
                              return;
                            }

                            // ==================================
                            // ERROR MESSAGE
                            // ==================================
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
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

  // ============================================================
  // DISPLAY RISK
  // ============================================================
  //
  // Firestore/model can contain:
  //
  // Low       -> Low
  // Medium    -> Medium
  // Moderate  -> Medium
  // High      -> High
  // Extreme   -> High
  //
  // This only changes what is displayed in the table.
  // It does NOT change the Firestore value.
  //
  String _displayRisk(String risk) {
    switch (risk.trim().toLowerCase()) {
      case "low":
        return "Low";

      case "medium":
        return "Medium";

      case "moderate":
        return "Medium";

      case "high":
        return "High";

      case "extreme":
        return "High";

      default:
        return risk;
    }
  }

  // ============================================================
  // RISK COLOR
  // ============================================================
  Color _riskColor(String risk) {
    switch (risk.trim().toLowerCase()) {

    // ==========================
    // LOW
    // ==========================
      case "low":
        return Colors.green;

    // ==========================
    // MEDIUM / MODERATE
    // ==========================
      case "medium":
      case "moderate":
        return Colors.orange;

    // ==========================
    // HIGH / EXTREME
    // ==========================
      case "high":
      case "extreme":
        return Colors.red;

    // ==========================
    // UNKNOWN
    // ==========================
      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================
  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {

    // ==========================
    // ACTIVE
    // ==========================
      case "active":
        return Colors.red;

    // ==========================
    // MONITORING
    // ==========================
      case "monitoring":
        return Colors.orange;

    // ==========================
    // SAFE
    // ==========================
      case "safe":
        return Colors.green;

    // ==========================
    // UNKNOWN
    // ==========================
      default:
        return Colors.grey;
    }
  }
}
