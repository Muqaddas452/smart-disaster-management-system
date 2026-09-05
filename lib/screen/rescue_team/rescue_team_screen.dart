import 'package:flutter/material.dart';

import '../../model/rescue_team_model.dart';
import '../../services/rescue_team_service.dart';

import '../../widget/rescue_team/add_edit_team_dialog.dart';
import '../../widget/rescue_team/rescue_statistics.dart';
import '../../widget/rescue_team/rescue_team_table.dart';

class RescueTeamScreen extends StatefulWidget {
  const RescueTeamScreen({super.key});

  @override
  State<RescueTeamScreen> createState() =>
      _RescueTeamScreenState();
}

class _RescueTeamScreenState
    extends State<RescueTeamScreen> {
  final RescueTeamService _service =
  RescueTeamService();

  String _search = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Rescue Teams"),
        centerTitle: false,
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Team"),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) =>
            const AddEditTeamDialog(),
          );
        },
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            /// Statistics
             RescueStatistics(),

            const SizedBox(height: 20),

            /// Search
            TextField(
              decoration: InputDecoration(
                hintText:
                "Search by team, leader or area",
                prefixIcon:
                const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                filled: true,
              ),

              onChanged: (value) {
                setState(() {
                  _search =
                      value.toLowerCase().trim();
                });
              },
            ),

            const SizedBox(height: 20),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return StreamBuilder<List<RescueTeam>>(
                    stream: _service.getRescueTeams(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error : ${snapshot.error}",
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            "No Rescue Teams Found",
                            style: TextStyle(fontSize: 18),
                          ),
                        );
                      }

                      List<RescueTeam> teams = snapshot.data!;

                      if (_search.isNotEmpty) {
                        teams = teams.where((team) {
                          return team.teamName
                              .toLowerCase()
                              .contains(_search) ||
                              team.leader
                                  .toLowerCase()
                                  .contains(_search) ||
                              team.assignedArea
                                  .toLowerCase()
                                  .contains(_search) ||
                              team.vehicle
                                  .toLowerCase()
                                  .contains(_search);
                        }).toList();
                      }

                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: RescueTeamTable(
                            rescueTeams: teams,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}