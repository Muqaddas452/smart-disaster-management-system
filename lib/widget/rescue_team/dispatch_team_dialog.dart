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

  final ReportService _reportService =
  ReportService();

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
            ? const Center(
          child:
          CircularProgressIndicator(),
        )
            : StreamBuilder<List<Report>>(

          stream:
          _reportService.getReports(),

          builder:
              (context, snapshot) {

            if (!snapshot.hasData) {
              return const Center(
                child:
                CircularProgressIndicator(),
              );
            }

            final reports = snapshot.data!
                .where(
                  (r) =>
              r.status !=
                  "Resolved",
            )
                .toList();

            if (reports.isEmpty) {
              return const Text(
                "No pending reports available.",
              );
            }

            return DropdownButtonFormField<
                Report>(

              value: selectedReport,

              decoration:
              const InputDecoration(
                labelText:
                "Select Report",
                border:
                OutlineInputBorder(),
              ),

              items: reports
                  .map(
                    (report) =>
                    DropdownMenuItem(
                      value: report,
                      child: Text(
                        "${report.emergencyType} - ${report.reporterName}",
                      ),
                    ),
              )
                  .toList(),

              onChanged: (value) {
                setState(() {
                  selectedReport =
                      value;
                });
              },
            );
          },
        ),
      ),

      actions: [

        OutlinedButton(

          onPressed: () {
            Navigator.pop(context);
          },

          child: const Text("Cancel"),
        ),

        ElevatedButton.icon(

          icon: const Icon(Icons.send),

          label: const Text("Dispatch"),

          onPressed: () async {

            if (selectedReport == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
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

            await _teamService.dispatchTeam(

              teamId: widget.team.id,

              reportId: selectedReport!.id,

              area:
              "Lat: ${selectedReport!.latitude}, Lng: ${selectedReport!.longitude}",

            );

            /// only updates report status
            /// does NOT change report UI

            await _reportService.assignReport(
              selectedReport!.id,
            );

            if (!mounted) return;

            Navigator.pop(context);

            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                backgroundColor:
                Colors.green,
                content: Text(
                  "Rescue Team Dispatched Successfully",
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}