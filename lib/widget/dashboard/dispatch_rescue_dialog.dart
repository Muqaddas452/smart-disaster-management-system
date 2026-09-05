import 'package:flutter/material.dart';

import '../../model/report_model.dart';
import '../../model/rescue_team_model.dart';
import '../../services/report_service.dart';
import '../../services/rescue_team_service.dart';

class DispatchRescueDialog extends StatefulWidget {
  const DispatchRescueDialog({super.key});

  @override
  State<DispatchRescueDialog> createState() =>
      _DispatchRescueDialogState();
}

class _DispatchRescueDialogState
    extends State<DispatchRescueDialog> {
  final ReportService _reportService = ReportService();
  final RescueTeamService _teamService = RescueTeamService();

  Report? selectedReport;
  RescueTeam? selectedTeam;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Dispatch Rescue Team"),

      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// REPORTS
            StreamBuilder<List<Report>>(
              stream: _reportService.getReports(),
              builder: (context, reportSnapshot) {

                if (!reportSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final reports = reportSnapshot.data!
                    .where((r) =>
                r.status.toLowerCase() != "resolved")
                    .toList();

                return DropdownButtonFormField<Report>(
                  value: selectedReport,

                  decoration: const InputDecoration(
                    labelText: "Select Report",
                    border: OutlineInputBorder(),
                  ),

                  items: reports.map((report) {
                    return DropdownMenuItem(
                      value: report,
                      child: Text(
                        "${report.emergencyType} - ${report.reporterName}",
                      ),
                    );
                  }).toList(),

                  onChanged: (value) {
                    setState(() {
                      selectedReport = value;
                    });
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            /// AVAILABLE TEAMS
            StreamBuilder<List<RescueTeam>>(
              stream: _teamService.getRescueTeams(),
              builder: (context, teamSnapshot) {

                if (!teamSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final teams = teamSnapshot.data!
                    .where((t) =>
                t.status.toLowerCase() == "available")
                    .toList();

                return DropdownButtonFormField<RescueTeam>(
                  value: selectedTeam,

                  decoration: const InputDecoration(
                    labelText: "Available Rescue Team",
                    border: OutlineInputBorder(),
                  ),

                  items: teams.map((team) {
                    return DropdownMenuItem(
                      value: team,
                      child: Text(team.teamName),
                    );
                  }).toList(),

                  onChanged: (value) {
                    setState(() {
                      selectedTeam = value;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: () async {

            if (selectedReport == null ||
                selectedTeam == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Please select report and rescue team.",
                  ),
                ),
              );
              return;
            }

            /// Dispatch Team
            await _teamService.dispatchTeam(
              teamId: selectedTeam!.id,
              reportId: selectedReport!.id,
              area:
              "${selectedReport!.latitude}, ${selectedReport!.longitude}",            );

            /// Update report status
            await _reportService.assignReport(
              selectedReport!.id,
            );

            if (!mounted) return;

            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.green,
                content: Text(
                  "Rescue Team Dispatched Successfully",
                ),
              ),
            );
          },
          child: const Text("Dispatch"),
        ),
      ],
    );
  }
}