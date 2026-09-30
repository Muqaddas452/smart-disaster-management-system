import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Leader-only screen: pick which team members this accepted task gets
// dispatched to. Writing assignedMemberIds + assignedMembers on the task
// moves its status from "accepted" to "assigned".
class AssignMembersScreen extends StatefulWidget {
  final String taskId;
  final String teamId;
  const AssignMembersScreen({super.key, required this.taskId, required this.teamId});

  @override
  State<AssignMembersScreen> createState() => _AssignMembersScreenState();
}

class _AssignMembersScreenState extends State<AssignMembersScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  final Set<String> _selectedUids = {};
  bool _isDispatching = false;

  // Active statuses that mean a member is currently out on a task and
  // should show as "Busy" instead of "Available".
  static const List<String> _activeTaskStatuses = ['assigned', 'enroute', 'in_progress'];

  // Checks whether this member currently has an active (not yet resolved)
  // task assigned to them.
  Future<bool> _isMemberBusy(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedMemberIds', arrayContains: uid)
        .where('status', whereIn: _activeTaskStatuses)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _dispatch(List<QueryDocumentSnapshot<Map<String, dynamic>>> members) async {
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one team member')),
      );
      return;
    }

    setState(() => _isDispatching = true);

    final assignedMembers = members
        .where((m) => _selectedUids.contains(m.id))
        .map((m) => {'uid': m.id, 'name': m.data()['name'] ?? 'Member'})
        .toList();

    try {
      await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).update({
        'assignedMemberIds': _selectedUids.toList(),
        'assignedMembers': assignedMembers,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task dispatched to selected members'), backgroundColor: kGreen),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not dispatch: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  // Small colored pill: Offline (grey) takes priority in the display since a
  // member who isn't online can't be dispatched right now anyway; otherwise
  // Busy (orange) if they're already on an active task, else Available (green).
  Widget _statusChip({required bool isOnline, required bool isBusy}) {
    late final Color color;
    late final Color bg;
    late final String label;

    if (!isOnline) {
      color = Colors.black54;
      bg = Colors.grey.shade200;
      label = 'Offline';
    } else if (isBusy) {
      color = const Color(0xFF8A5300);
      bg = const Color(0xFFFAEEDA);
      label = 'Busy — on a task';
    } else {
      color = kGreen;
      bg = const Color(0xFFE6F4EA);
      label = 'Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
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
        title: const Text('Assign Team Members',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: widget.teamId.trim().isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not determine your team. Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('rescueTeamUsers')
            .where('teamId', isEqualTo: widget.teamId)
            .where('isLeader', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          final members = snapshot.data?.docs ?? [];
          if (members.isEmpty) {
            return const Center(child: Text('No team members found'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final name = m.data()['name'] ?? 'Member';
                    final specialization = m.data()['specialization'] ?? '';
                    // Older member docs won't have this field yet, so default
                    // to "online" rather than wrongly showing everyone offline.
                    final bool isOnline = m.data()['isOnline'] ?? true;
                    final selected = _selectedUids.contains(m.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? kGreen : Colors.grey.shade200, width: selected ? 1.5 : 1),
                      ),
                      child: CheckboxListTile(
                        activeColor: kGreen,
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedUids.add(m.id);
                            } else {
                              _selectedUids.remove(m.id);
                            }
                          });
                        },
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (specialization.toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(specialization,
                                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                ),
                              FutureBuilder<bool>(
                                future: _isMemberBusy(m.id),
                                builder: (context, statusSnap) {
                                  // While the busy-check is loading, don't
                                  // block on it — fall back to "available"
                                  // look until we know for sure.
                                  final bool isBusy = statusSnap.data ?? false;
                                  return _statusChip(isOnline: isOnline, isBusy: isBusy);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isDispatching ? null : () => _dispatch(members),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isDispatching
                        ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Dispatch selected members',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}