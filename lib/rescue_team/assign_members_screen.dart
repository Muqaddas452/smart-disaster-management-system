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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                        subtitle: specialization.toString().isNotEmpty
                            ? Text(specialization, style: const TextStyle(fontSize: 12, color: Colors.black45))
                            : null,
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