import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../model/rescue_team_model.dart';
import '../../services/rescue_team_service.dart';

import '../common/glass_card.dart';
import '../common/live_pulse.dart';
import '../common/section_header.dart';
import '../common/status_badge.dart';

class RescueTeamPanel extends StatelessWidget {
  RescueTeamPanel({super.key});

  final RescueTeamService _service = RescueTeamService();

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "available":
        return Colors.green;

      case "on mission":
      case "busy":
        return Colors.orange;

      case "offline":
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 430,
      child: GlassCard(
        hoverable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    icon: Icons.groups,
                    title: "Rescue Teams",
                    subtitle: "Live Firebase Data",
                  ),
                ),
                LivePulse(),
              ],
            ),

            const SizedBox(height: 15),

            Expanded(
              child: StreamBuilder<List<RescueTeam>>(
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
                        snapshot.error.toString(),
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    );
                  }

                  final teams = snapshot.data ?? [];

                  if (teams.isEmpty) {
                    return const Center(
                      child: Text(
                        "No Rescue Teams",
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  final latestTeams = teams.take(5).toList();

                  return ListView.builder(
                    itemCount: latestTeams.length,
                    itemBuilder: (context, index) {
                      final team = latestTeams[index];

                      final color = statusColor(team.status);

                      return Padding(
                        padding:
                        const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding:
                          const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius:
                            BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                color.withOpacity(.15),
                                child: Icon(
                                  Icons.groups,
                                  color: color,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team.teamName,
                                      style: const TextStyle(
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      "Leader: ${team.leader}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),

                                    Text(
                                      "Members: ${team.members}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),

                                    Text(
                                      "Vehicle: ${team.vehicle}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),

                                    Text(
                                      "Area: ${team.assignedArea.isEmpty ? "-" : team.assignedArea}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              StatusBadge(
                                label: team.status,
                                color: color,
                              ),
                            ],
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