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

  Future<void> updateStatus(String status) async {
    setState(() {
      loading = true;
    });

    try {
      await _service.updateStatus(
        widget.report.id,
        status,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
          ),
        );
      }
    }
  }

  Future deleteReport() async {
    final delete = await showDialog(
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
      await _service.deleteReport(widget.report.id);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
          ),
        );
      }
    }
  }

  Widget infoTile(
      String title,
      String value,
      IconData icon,
      ) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Dialog(
      child: SizedBox(
        width: 650,
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

                Center(
                  child: ReportImage(
                    imageUrl: report.imageUrl,
                  ),
                ),

                const SizedBox(height: 20),

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
                  "Phone_Number",
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

                const Text(
                  "Description",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 8),

                Text(report.description),

                const SizedBox(height: 20),

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
                      status: report.status,
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [

                    ElevatedButton.icon(
                      icon: const Icon(Icons.pending),
                      label: const Text("Pending"),
                      onPressed: () {
                        updateStatus("Pending");
                      },
                    ),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.engineering),
                      label: const Text("Working"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        updateStatus("In Progress");
                      },
                    ),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text("Resolved"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        updateStatus("Resolved");
                      },
                    ),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: deleteReport,
                    ),

                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Close"),
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