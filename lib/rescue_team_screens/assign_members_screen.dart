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

  static const List<String> _activeTaskStatuses = ['assigned', 'enroute', 'in_progress'];

  @override
  void initState() {
    super.initState();
    _preselectCurrentMembers();
  }

  // "Reassign Members" pehle khali list se shuru hota tha — leader ko sab
  // dobara tick karne parte the, warna purane members chupke se hat jate the.
  Future<void> _preselectCurrentMembers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).get();
      final ids = List.from(snap.data()?['assignedMemberIds'] ?? []);
      if (mounted && ids.isNotEmpty) {
        setState(() => _selectedUids.addAll(ids.map((e) => e.toString())));
      }
    } catch (_) {}
  }

  // Busy = kisi AUR active task par assigned aur us par apna hissa abhi
  // 'completed' nahi kiya. (Pehle: task-level status dekha jata tha, to
  // member apna kaam khatam kar ke bhi Busy dikhta tha; aur har checkbox tap
  // par har row ek nayi Firestore query chalati thi, jo composite index ke
  // baghair silently fail ho kar sab ko "Available" dikha deti thi.)
  Set<String> _busyUids(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final busy = <String>{};
    for (final d in docs) {
      if (d.id == widget.taskId) continue; // yehi task ginti mein nahi
      final data = d.data();
      if (!_activeTaskStatuses.contains(data['status'])) continue;
      final ids = List.from(data['assignedMemberIds'] ?? []);
      final statuses = Map<String, dynamic>.from(data['memberStatuses'] ?? {});
      for (final id in ids) {
        if (statuses[id] != 'completed') busy.add(id.toString());
      }
    }
    return busy;
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
      final taskRef = FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);

      // Jo members is dafa hata diye gaye, un ka purana status aur live
      // location task se saaf karo, warna wo ghost marker/status ban kar
      // reh jate the (aur unka phone location likhta rehta tha).
      final before = await taskRef.get();
      final oldIds =
      List.from(before.data()?['assignedMemberIds'] ?? []).map((e) => e.toString()).toSet();
      final removed = oldIds.difference(_selectedUids);

      final Map<String, dynamic> updates = {
        'assignedMemberIds': _selectedUids.toList(),
        'assignedMembers': assignedMembers,
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      };
      for (final uid in removed) {
        updates['memberStatuses.$uid'] = FieldValue.delete();
        updates['memberLocations.$uid'] = FieldValue.delete();
      }
      await taskRef.update(updates);

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

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('teamId', isEqualTo: widget.teamId)
                .snapshots(),
            builder: (context, taskSnap) {
              final Set<String> busyUids = _busyUids(taskSnap.data?.docs ?? []);
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
                                  _statusChip(isOnline: isOnline, isBusy: busyUids.contains(m.id)),
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
          );
        },
      ),
    );
  }
}