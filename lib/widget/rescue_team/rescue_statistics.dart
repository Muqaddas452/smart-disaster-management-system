import 'package:flutter/material.dart';
import '../../services/rescue_team_service.dart';

class RescueStatistics extends StatelessWidget {
  RescueStatistics({super.key});

  final RescueTeamService _service = RescueTeamService();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        Expanded(
          child: _buildCard(
            title: "Total Teams",
            color: Colors.blue,
            stream: _service.totalTeams(),
            icon: Icons.groups,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _buildCard(
            title: "Pending",
            color: Colors.orange,
            stream: _service.pendingTeams(),
            icon: Icons.hourglass_top,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _buildCard(
            title: "Available",
            color: Colors.green,
            stream: _service.availableTeams(),
            icon: Icons.check_circle,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: _buildCard(
            title: "On Mission",
            color: Colors.red,
            stream: _service.missionTeams(),
            icon: Icons.local_shipping,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required Color color,
    required Stream<int> stream,
    required IconData icon,
  }) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {

        final count = snapshot.data ?? 0;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [

                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(.15),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [

                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "$count",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}