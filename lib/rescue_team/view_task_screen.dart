import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'assign_members_screen.dart';

// Shared Task Details screen for BOTH leader and member.
// Buttons shown depend on (a) the signed-in user's role and (b) the task's
// current status, so the whole dispatched -> accepted -> assigned ->
// in_progress -> resolved lifecycle lives in this one screen.
class ViewTaskScreen extends StatefulWidget {
  final String taskId;
  const ViewTaskScreen({super.key, required this.taskId});

  @override
  State<ViewTaskScreen> createState() => _ViewTaskScreenState();
}

class _ViewTaskScreenState extends State<ViewTaskScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  bool _isLeader = false;
  String? _uid;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).get();
    final data = doc.data() ?? {};
    final role = data['role'] ?? '';
    if (mounted) {
      setState(() {
        _isLeader = data['isLeader'] == true || role == 'rescue_leader' || role == 'team_leader';
      });
    }
  }

  DocumentReference<Map<String, dynamic>> get _taskRef =>
      FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);

  Future<void> _acceptTask() async {
    setState(() => _busy = true);
    try {
      await _taskRef.update({
        'status': 'accepted',
        'acceptedBy': _uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showMessage('Could not accept task: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTask() async {
    setState(() => _busy = true);
    try {
      await _taskRef.update({
        'status': 'in_progress',
        'startedBy': _uid,
        'startedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showMessage('Could not start task: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markCompleted() async {
    setState(() => _busy = true);
    try {
      await _taskRef.update({
        'status': 'resolved',
        'resolvedBy': _uid,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showMessage('Could not mark task completed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        backgroundColor: kGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Task Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _taskRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Task not found'));
          }

          final data = snapshot.data!.data() ?? {};
          final String type = data['type'] ?? 'Task';
          final String priority = (data['priority'] ?? 'medium').toString().toLowerCase();
          final String description = data['description'] ?? '-';
          final String address = data['address'] ?? 'Address not available';
          final double? lat = (data['lat'] as num?)?.toDouble();
          final double? lng = (data['lng'] as num?)?.toDouble();
          final String status = data['status'] ?? 'dispatched';
          final List assignedMembers = data['assignedMembers'] ?? [];

          final priorityColors = {
            'high': const [Color(0xFFFCEBEB), Color(0xFF791F1F)],
            'medium': const [Color(0xFFFAEEDA), Color(0xFF633806)],
            'low': const [Color(0xFFE6F1FB), Color(0xFF042C53)],
          };
          final colors = priorityColors[priority] ?? priorityColors['medium']!;

          final bool amAssignedMember =
              (data['assignedMemberIds'] as List?)?.contains(_uid) ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration:
                          BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(20)),
                          child: Text('${priority[0].toUpperCase()}${priority.substring(1)} priority',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors[1])),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Text('Emergency: $type',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 16),
                      const Text('DESCRIPTION',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                      const SizedBox(height: 18),
                      const Text('LOCATION',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 18, color: kGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(address,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  if (lat != null && lng != null) ...[
                                    const SizedBox(height: 3),
                                    Text('Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (assignedMembers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('ASSIGNED TEAM MEMBERS',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: assignedMembers.map((m) {
                        final name = (m is Map ? m['name'] : null) ?? 'Member';
                        return ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F4FD),
                              child: Icon(Icons.person, color: kGreen, size: 20)),
                          title: Text(name, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                _actionArea(status, amAssignedMember, data),
              ],
            ),
          );
        },
      ),
    );
  }

  // Decides which button(s) to show based on role + current status.
  Widget _actionArea(String status, bool amAssignedMember, Map<String, dynamic> data) {
    // LEADER actions
    if (_isLeader) {
      if (status == 'dispatched') {
        return _primaryButton('Accept task', Icons.check, _busy ? null : _acceptTask);
      }
      if (status == 'accepted') {
        return _primaryButton('Assign to team members', Icons.group_add, _busy
            ? null
            : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssignMembersScreen(
                taskId: widget.taskId,
                teamId: data['teamId'] ?? '',
              ),
            ),
          );
        });
      }
      // assigned / in_progress / resolved -> leader just monitors, no action button
      return _statusNote(status);
    }

    // MEMBER actions (only if this member is actually assigned to the task)
    if (amAssignedMember) {
      if (status == 'assigned') {
        return _primaryButton('Start task', Icons.play_arrow, _busy ? null : _startTask);
      }
      if (status == 'in_progress') {
        return _primaryButton('Mark completed', Icons.task_alt, _busy ? null : _markCompleted);
      }
    }

    return _statusNote(status);
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _statusNote(String status) {
    final labels = {
      'assigned': 'Waiting for the assigned member to start this task',
      'in_progress': 'This task is currently in progress',
      'resolved': 'This task has been resolved',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Text(labels[status] ?? 'Status: $status',
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13)),
    );
  }
}