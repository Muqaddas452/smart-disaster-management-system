import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartdisaster/rescue_team_screens/view_task_screen.dart';

// Opened when a MEMBER taps "Update Rescue Status" on the home screen.
// This screen itself has no action buttons — it's just a filtered list of
// "tasks assigned to me". Tapping a task opens ViewTaskScreen, which already
// shows the one correct next-step button for that task's current status
// (Mark as Enroute / I've Arrived / Mark completed). Keeping the buttons
// only in ViewTaskScreen avoids having two different places that can change
// the same status.
class MemberStatusListScreen extends StatelessWidget {
  const MemberStatusListScreen({super.key});

  static const Color kGreen = Color(0xFF1B5E38);

  static const Map<String, Color> _statusColors = {
    'assigned': Color(0xFFB25E00),
    'enroute': Color(0xFF1A4FA0),
    'in_progress': Color(0xFF1B5E38),
    'resolved': Color(0xFF6B6B6B),
    'rejected': Color(0xFFB3261E),
  };

  static const Map<String, String> _statusLabels = {
    'assigned': 'Assigned',
    'enroute': 'Enroute',
    'in_progress': 'In Progress',
    'resolved': 'Resolved',
    'rejected': 'Rejected',
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text('My Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('assignedMemberIds', arrayContains: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No tasks assigned to you yet.', style: TextStyle(color: Colors.black54)),
            );
          }

          // Active tasks first, resolved/rejected pushed to the bottom
          // and shown dimmed — they're history, not something to act on.
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
    final String status = data['status'] ?? 'assigned';
    final color = _statusColors[status] ?? Colors.grey;
    final label = _statusLabels[status] ?? status;

    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(address, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ViewTaskScreen(taskId: taskId)));
          },
        ),
      ),
    );
  }
}