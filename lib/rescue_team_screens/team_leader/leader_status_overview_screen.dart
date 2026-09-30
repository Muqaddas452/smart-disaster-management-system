import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartdisaster/rescue_team_screens/view_task_screen.dart';

// Opened when the LEADER taps "Update Rescue Status" on the home screen.
// Unlike the member's list, this is a MONITORING view, not an action list —
// the leader doesn't set a member's status directly here. Each card just
// shows where every one of the team's tasks currently stands. Tapping a
// task opens ViewTaskScreen, where the leader can also reach the emergency
// "Override status" option if a member is unreachable.
class LeaderStatusOverviewScreen extends StatelessWidget {
  final String teamId;
  const LeaderStatusOverviewScreen({super.key, required this.teamId});

  static const Color kGreen = Color(0xFF1B5E38);

  static const Map<String, Color> _statusColors = {
    'dispatched': Color(0xFF6B6B6B),
    'accepted': Color(0xFF1A4FA0),
    'assigned': Color(0xFFB25E00),
    'enroute': Color(0xFF1A4FA0),
    'in_progress': Color(0xFF1B5E38),
    'resolved': Color(0xFF6B6B6B),
    'rejected': Color(0xFFB3261E),
  };

  static const Map<String, String> _statusLabels = {
    'dispatched': 'Dispatched',
    'accepted': 'Accepted',
    'assigned': 'Assigned',
    'enroute': 'Enroute',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
    'rejected': 'Rejected',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text('Team Task Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('teamId', isEqualTo: teamId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No tasks for your team yet.', style: TextStyle(color: Colors.black54)),
            );
          }

          final active = docs.where((d) {
            final s = d.data()['status'] ?? '';
            return s != 'resolved' && s != 'rejected';
          }).toList();
          final done = docs.where((d) {
            final s = d.data()['status'] ?? '';
            return s == 'resolved' || s == 'rejected';
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              ...active.map((d) => _taskTile(context, d.id, d.data(), dim: false)),
              if (done.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('COMPLETED / CLOSED',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1)),
                ),
                ...done.map((d) => _taskTile(context, d.id, d.data(), dim: true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _taskTile(BuildContext context, String taskId, Map<String, dynamic> data, {required bool dim}) {
    final String type = data['type'] ?? 'Task';
    final String address = data['address'] ?? 'Location unavailable';
    final String status = data['status'] ?? 'dispatched';
    final List assignedMembers = data['assignedMembers'] ?? [];
    final String memberSummary = assignedMembers.isEmpty
        ? 'Not yet assigned'
        : assignedMembers.map((m) => (m is Map ? m['name'] : null) ?? 'Member').join(', ');
    final color = _statusColors[status] ?? Colors.grey;
    final label = _statusLabels[status] ?? status;
    final overridden = data['statusOverriddenBy'] != null && status != 'resolved' && status != 'rejected';

    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ViewTaskScreen(taskId: taskId)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(address, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(memberSummary, style: const TextStyle(fontSize: 12, color: Colors.black45)),
              if (overridden) ...[
                const SizedBox(height: 4),
                const Text('Manually overridden',
                    style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}