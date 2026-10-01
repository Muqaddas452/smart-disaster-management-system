import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void _showMembersDialog(
      BuildContext context,
      RescueTeam team,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            "${team.teamName} - Members",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 450,
            child: members.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No invited members found."),
            )
                : ListView.separated(
              shrinkWrap: true,
              itemCount: members.length,
              separatorBuilder: (_, __) =>
              const Divider(),
              itemBuilder: (context, index) {
                final data = members[index].data();

                final email =
                    data["email"]?.toString() ?? "No email";

                final status =
                    data["status"]?.toString() ?? "Unknown";

                final isAccepted =
                    status.toLowerCase() == "accepted";

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    Colors.green.withOpacity(0.12),
                    child: const Icon(
                      Icons.person,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(
                    email,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text("Status: $status"),
                  trailing: Icon(
                    isAccepted
                        ? Icons.check_circle
                        : Icons.schedule,
                    color: isAccepted
                        ? Colors.green
                        : Colors.orange,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
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
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
          MaterialStateProperty.all(Colors.grey.shade200),

          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),

          columnSpacing: 28,
          horizontalMargin: 20,

          columns: const [
            DataColumn(label: Text("Team")),
            DataColumn(label: Text("Leader")),
            DataColumn(label: Text("Members")),
            DataColumn(label: Text("Member Details")),
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

                // Members invited to this team
                DataCell(
                  StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('teamInvitations')
                        .where(
                      'teamId',
                      isEqualTo: team.id,
                    )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          "Unable to load",
                          style: TextStyle(color: Colors.red),
                        );
                      }

                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        );
                      }

                      final members =
                          snapshot.data?.docs ?? [];

                      if (members.isEmpty) {
                        return const Text(
                          "No members",
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return TextButton.icon(
                        onPressed: () {
                          _showMembersDialog(
                            context,
                            team,
                            members,
                          );
                        },
                        icon: const Icon(
                          Icons.groups,
                          size: 19,
                        ),
                        label: Text(
                          "View (${members.length})",
                        ),
                      );
                    },
                  ),
                ),

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor(team.status)
                          .withOpacity(.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      team.status,
                      style: TextStyle(
                        color: statusColor(team.status),
                        fontWeight: FontWeight.bold,
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
                          builder: (_) => AddEditTeamDialog(
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
    );
  }
}