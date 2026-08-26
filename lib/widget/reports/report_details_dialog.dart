import 'package:flutter/material.dart';

import '../../model/report_model.dart';
import '../../services/report_service.dart';
import 'report_image.dart';
import 'status_chip.dart';

class ReportDetailsDialog extends StatefulWidget {
  final Report report;

  const ReportDetailsDialog({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailsDialog> createState() =>
      _ReportDetailsDialogState();
}

class _ReportDetailsDialogState
    extends State<ReportDetailsDialog> {
  final ReportService _service = ReportService();

  bool loading = false;

  // ============================================================
  // DISPLAY STATUS
  // ============================================================
  // Firestore:
  // "In Progress"
  //
  // UI:
  // "Working"
  // ============================================================

  String _displayStatus(String status) {
    if (status.trim().toLowerCase() == "in progress") {
      return "Working";
    }

    // Also support old records that may contain "Assigned"
    if (status.trim().toLowerCase() == "assigned") {
      return "Working";
    }

    return status;
  }

  // ============================================================
  // UPDATE REPORT STATUS
  // ============================================================

  Future<void> updateStatus(String status) async {
    setState(() {
      loading = true;
    });

    try {
      await _service.updateStatus(
        widget.report.id,
        status,
      );

      if (!mounted) return;

      final displayStatus = _displayStatus(status);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Report status changed to $displayStatus",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error updating status: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE REPORT
  // ============================================================

  Future<void> deleteReport() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Report"),
          content: const Text(
            "Are you sure you want to delete this report?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (delete != true) return;

    setState(() {
      loading = true;
    });

    try {
      await _service.deleteReport(
        widget.report.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Report deleted successfully.",
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error deleting report: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // INFORMATION TILE
  // ============================================================

  Widget infoTile(
      String title,
      String value,
      IconData icon,
      ) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        value.isEmpty ? "-" : value,
      ),
    );
  }

  // ============================================================
  // STATUS BUTTON
  // ============================================================

  Widget statusButton({
    required String label,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: loading
          ? null
          : () {
        updateStatus(status);
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    // Convert database status to user-friendly status.
    final String displayStatus =
    _displayStatus(report.status);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 650,
          maxHeight: 700,
        ),
        child: loading
            ? const Padding(
          padding: EdgeInsets.all(50),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                // ==================================================
                // TITLE
                // ==================================================

                const Center(
                  child: Text(
                    "Report Details",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // IMAGE
                // ==================================================

                Center(
                  child: ReportImage(
                    imageUrl: report.imageUrl,
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // REPORT INFORMATION
                // ==================================================

                infoTile(
                  "Reporter",
                  report.reporterName,
                  Icons.person,
                ),

                infoTile(
                  "Disaster",
                  report.emergencyType,
                  Icons.warning,
                ),

                infoTile(
                  "Phone Number",
                  report.phoneNumber,
                  Icons.phone,
                ),

                infoTile(
                  "Coordinates",
                  "${report.latitude}, ${report.longitude}",
                  Icons.location_on,
                ),

                infoTile(
                  "Severity",
                  report.severity,
                  Icons.priority_high,
                ),

                infoTile(
                  "Date",
                  report.formattedDate,
                  Icons.calendar_today,
                ),

                infoTile(
                  "Time",
                  report.formattedTime,
                  Icons.access_time,
                ),

                const SizedBox(height: 10),

                // ==================================================
                // DESCRIPTION
                // ==================================================

                const Text(
                  "Description",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius:
                    BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.description.isEmpty
                        ? "No description provided."
                        : report.description,
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // CURRENT STATUS
                // ==================================================

                Row(
                  children: [
                    const Text(
                      "Current Status:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 10),

                    StatusChip(
                      status: displayStatus,
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // ==================================================
                // CHANGE STATUS
                // ==================================================

                const Text(
                  "Change Status",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [

                    // ============================================
                    // PENDING
                    // ============================================

                    statusButton(
                      label: "Pending",
                      status: "Pending",
                      icon: Icons.pending,
                      color: Colors.orange,
                    ),

                    // ============================================
                    // WORKING
                    //
                    // IMPORTANT:
                    // UI = Working
                    // FIRESTORE = In Progress
                    // ============================================

                    statusButton(

                      label: "Working",
                      status: "Working",
                      icon: Icons.engineering,
                      color: Colors.blue,
                    ),

                    // ============================================
                    // RESOLVED
                    // ============================================

                    statusButton(
                      label: "Resolved",
                      status: "Resolved",
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),

                    // ============================================
                    // DELETE
                    // ============================================

                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.delete,
                      ),
                      label: const Text(
                        "Delete",
                      ),
                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor:
                        Colors.red,
                        foregroundColor:
                        Colors.white,
                      ),
                      onPressed:
                      loading
                          ? null
                          : deleteReport,
                    ),

                    // ============================================
                    // CLOSE
                    // ============================================

                    OutlinedButton(
                      onPressed: loading
                          ? null
                          : () {
                        Navigator.pop(
                          context,
                        );
                      },
                      child: const Text(
                        "Close",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}