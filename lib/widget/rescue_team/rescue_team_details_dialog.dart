import 'package:flutter/material.dart';

import '../../model/rescue_team_model.dart';
import '../../services/rescue_team_service.dart';

import 'add_edit_team_dialog.dart';
import 'dispatch_team_dialog.dart';

class RescueTeamDetailsDialog extends StatefulWidget {
  final RescueTeam team;

  const RescueTeamDetailsDialog({
    super.key,
    required this.team,
  });

  @override
  State<RescueTeamDetailsDialog> createState() =>
      _RescueTeamDetailsDialogState();
}

class _RescueTeamDetailsDialogState
    extends State<RescueTeamDetailsDialog> {

  final RescueTeamService _service = RescueTeamService();

  bool loading = false;

  Color statusColor() {
    switch (widget.team.status.toLowerCase()) {
      case "available":
        return Colors.green;

      case "pending":
        return Colors.orange;

      case "on mission":
        return Colors.blue;

      case "offline":
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  Widget tile(
      String title,
      String value,
      IconData icon,
      ) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.blue,
      ),
      title: Text(title),
      subtitle: Text(
        value.isEmpty ? "-" : value,
      ),
    );
  }

  Future approveTeam() async {
    setState(() => loading = true);

    await _service.approveTeam(widget.team.id);

    if (mounted) Navigator.pop(context);
  }

  Future completeMission() async {
    setState(() => loading = true);

    await _service.completeMission(
      widget.team.id,
      widget.team.assignedReportId,
    );

    if (mounted) Navigator.pop(context);
  }

  Future deleteTeam() async {

    final delete = await showDialog<bool>(

      context: context,

      builder: (_) {

        return AlertDialog(

          title: const Text("Delete Team"),

          content: const Text(
            "Are you sure you want to delete this rescue team?",
          ),

          actions: [

            TextButton(
              onPressed: (){
                Navigator.pop(context,false);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: (){
                Navigator.pop(context,true);
              },
              child: const Text("Delete"),
            )

          ],
        );
      },
    );

    if (delete != true) return;

    setState(() => loading = true);

    await _service.deleteRescueTeam(widget.team.id);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Dialog(

      child: SizedBox(

        width: 550,

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              const Text(
                "Rescue Team Details",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor:
                  statusColor().withOpacity(.15),
                  child: Icon(
                    Icons.groups,
                    color: statusColor(),
                    size: 42,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              tile(
                "Team Name",
                widget.team.teamName,
                Icons.groups,
              ),

              tile(
                "Leader",
                widget.team.leader,
                Icons.person,
              ),

              tile(
                "Phone",
                widget.team.phone,
                Icons.phone,
              ),

              tile(
                "Members",
                widget.team.members.toString(),
                Icons.people,
              ),

              tile(
                "Vehicle",
                widget.team.vehicle,
                Icons.local_shipping,
              ),

              tile(
                "Assigned Area",
                widget.team.assignedArea,
                Icons.location_city,
              ),

              tile(
                "Latitude",
                widget.team.latitude.toString(),
                Icons.my_location,
              ),

              tile(
                "Longitude",
                widget.team.longitude.toString(),
                Icons.location_on,
              ),

              ListTile(
                leading: const Icon(Icons.circle),
                title: const Text("Status"),
                subtitle: Text(
                  widget.team.status,
                  style: TextStyle(
                    color: statusColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text("Created"),
                subtitle: Text(
                  widget.team.createdAt.toString(),
                ),
              ),

              const SizedBox(height: 25),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [

                  // Approve button
                  if (widget.team.status.trim().toLowerCase() == "pending")
                    ElevatedButton.icon(
                      onPressed: approveTeam,
                      icon: const Icon(Icons.verified),
                      label: const Text("Approve"),
                    ),

                  // Dispatch button (only after approval)
                  if (widget.team.status.trim().toLowerCase() == "available")
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);

                        showDialog(
                          context: context,
                          builder: (_) => DispatchTeamDialog(
                            team: widget.team,
                          ),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text("Dispatch"),
                    ),

                  // Complete Mission button
                  if (widget.team.status.trim().toLowerCase() == "on mission")
                    ElevatedButton.icon(
                      onPressed: completeMission,
                      icon: const Icon(Icons.check),
                      label: const Text("Complete"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),

                  // Edit button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);

                      showDialog(
                        context: context,
                        builder: (_) => AddEditTeamDialog(
                          team: widget.team,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"),
                  ),

                  // Delete button
                  ElevatedButton.icon(
                    onPressed: deleteTeam,
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  // Close button
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
    );
  }
}