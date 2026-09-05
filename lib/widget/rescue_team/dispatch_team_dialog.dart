import 'package:flutter/material.dart';

import '../../model/report_model.dart';
import '../../model/rescue_team_model.dart';

import '../../services/report_service.dart';
import '../../services/rescue_team_service.dart';

class DispatchTeamDialog extends StatefulWidget {
  final RescueTeam team;

  const DispatchTeamDialog({
    super.key,
    required this.team,
  });

  @override
  State<DispatchTeamDialog> createState() =>
      _DispatchTeamDialogState();
}

class _DispatchTeamDialogState
    extends State<DispatchTeamDialog> {
  final ReportService _reportService = ReportService();

  final RescueTeamService _teamService =
  RescueTeamService();

  Report? selectedReport;

  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Dispatch Rescue Team",
      ),

      content: SizedBox(
        width: 450,
        child: loading
            ? const SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        )
            : StreamBuilder<List<Report>>(
          stream: _reportService.getReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child:
                  CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                "Error loading reports: "
                    "${snapshot.error}",
              );
            }

            final reports =
                snapshot.data ?? [];

            // Show reports that are not resolved.
            final availableReports =
            reports.where((report) {
              return report.status
                  .toLowerCase() !=
                  "resolved";
            }).toList();

            if (availableReports.isEmpty) {
              return const Padding(
                padding:
                EdgeInsets.all(20),
                child: Text(
                  "No pending reports available.",
                ),
              );
            }

            return DropdownButtonFormField<
                Report>(
              value: selectedReport,
              isExpanded: true,
              decoration:
              const InputDecoration(
                labelText: "Select Report",
                border:
                OutlineInputBorder(),
              ),
              items: availableReports
                  .map(
                    (report) =>
                    DropdownMenuItem<
                        Report>(
                      value: report,
                      child: Text(
                        "${report.emergencyType} - "
                            "${report.reporterName}",
                        overflow:
                        TextOverflow.ellipsis,
                      ),
                    ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedReport = value;
                });
              },
            );
          },
        ),
      ),

      actions: [
        OutlinedButton(
          onPressed: loading
              ? null
              : () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),

        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          label: const Text("Dispatch"),
          onPressed: loading
              ? null
              : _dispatchTeam,
        ),
      ],
    );
  }

  // ============================================================
  // DISPATCH TEAM
  // ============================================================

  Future<void> _dispatchTeam() async {
    if (selectedReport == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            "Please select a report.",
          ),
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final report = selectedReport!;

      // --------------------------------------------------------
      // 1. Dispatch rescue team
      // --------------------------------------------------------

      await _teamService.dispatchTeam(
        teamId: widget.team.id,
        reportId: report.id,
        area:
        "Lat: ${report.latitude}, "
            "Lng: ${report.longitude}",
      );

      // --------------------------------------------------------
      // 2. Change REPORT status to Working
      // --------------------------------------------------------

      await _reportService.assignReport(
        report.id,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Rescue Team Dispatched Successfully\n"
                "Report status changed to Working.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Dispatch failed: $e",
          ),
        ),
      );
    }
  }
}