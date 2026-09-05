import 'package:flutter/material.dart';

import '../../model/rescue_team_model.dart';
import 'add_edit_team_dialog.dart';
import 'rescue_team_details_dialog.dart';

class RescueTeamTable extends StatelessWidget {
  final List<RescueTeam> rescueTeams;

  const RescueTeamTable({
    super.key,
    required this.rescueTeams,
  });

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    if (rescueTeams.isEmpty) {
      return const Center(
        child: Text(
          "No Rescue Teams",
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,

        child: DataTable(

          headingRowColor:
          MaterialStateProperty.all(
            Colors.grey.shade200,
          ),

          columns: const [

            DataColumn(label: Text("Team")),

            DataColumn(label: Text("Leader")),

            DataColumn(label: Text("Members")),

            DataColumn(label: Text("Vehicle")),

            DataColumn(label: Text("Assigned Area")),

            DataColumn(label: Text("Status")),

            DataColumn(label: Text("Action")),
          ],

          rows: rescueTeams.map((team) {

            return DataRow(

              cells: [

                DataCell(Text(team.teamName)),

                DataCell(Text(team.leader)),

                DataCell(Text(team.members.toString())),

                DataCell(Text(team.vehicle)),

                DataCell(

                  Text(

                    team.assignedArea.isEmpty
                        ? "-"
                        : team.assignedArea,

                  ),
                ),

                DataCell(

                  Container(

                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(

                      color: statusColor(
                          team.status)
                          .withOpacity(.15),

                      borderRadius:
                      BorderRadius.circular(20),

                    ),

                    child: Text(

                      team.status,

                      style: TextStyle(

                        color: statusColor(
                            team.status),

                        fontWeight:
                        FontWeight.bold,

                      ),

                    ),

                  ),

                ),

                DataCell(

                  PopupMenuButton<String>(

                    onSelected: (value) {

                      if (value == "view") {

                        showDialog(

                          context: context,

                          builder: (_) =>
                              RescueTeamDetailsDialog(
                                team: team,
                              ),

                        );
                      }

                      if (value == "edit") {

                        showDialog(

                          context: context,

                          builder: (_) =>
                              AddEditTeamDialog(
                                team: team,
                              ),

                        );
                      }

                    },

                    itemBuilder: (_) => const [

                      PopupMenuItem(
                        value: "view",
                        child: Text("View"),
                      ),

                      PopupMenuItem(
                        value: "edit",
                        child: Text("Edit"),
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
    );
  }
}