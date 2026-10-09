import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'view_task_screen.dart';
import 'add_task_screen.dart';
import 'package:smartdisaster/utils/priority_helper.dart';
import 'package:smartdisaster/database/rescue_dao.dart';
import 'package:smartdisaster/database/db_Helper.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({super.key});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  bool _isLoading = true;
  bool _isLeader = false;
  String? _teamId;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadRoleAndTeam();
  }

  Future<void> _loadRoleAndTeam() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    // FIXED: get(Source.cache) cache mein doc na ho to EXCEPTION throw karta
    // hai (non-existent doc nahi), jis se yeh function beech mein mar jata tha
    // aur Tasks screen hamesha spinner dikhati rehti thi (nayi install / login
    // ke baad pehli dafa). Ab cache fail ho to server se parhte hain.
    Map<String, dynamic> data = {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists) data = doc.data() ?? {};
    } catch (_) {}

    if (data.isEmpty) {
      try {
        final serverDoc =
        await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).get();
        data = serverDoc.data() ?? {};
      } catch (_) {}
    }

    _teamId = data['teamId'];
    final role = data['role'] ?? '';
    _isLeader = data['isLeader'] == true || role == 'rescue_leader' || role == 'team_leader';

    if (mounted) setState(() => _isLoading = false);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _taskStream() {
    final tasks = FirebaseFirestore.instance.collection('tasks');
    if (_isLeader) {
      return tasks.where('teamId', isEqualTo: _teamId).snapshots(includeMetadataChanges: true);
    }
    return tasks.where('assignedMemberIds', arrayContains: _uid).snapshots(includeMetadataChanges: true);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5E8),
        body: Column(
          children: [
            Container(
              color: kGreen,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.menu, color: Colors.white, size: 24),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text('My Tasks',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const TabBar(
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [Tab(text: 'Active'), Tab(text: 'Resolved')],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: (_isLoading || _uid == null)
                  ? Center(child: _uid == null ? const Text('User not logged in') : const CircularProgressIndicator(color: kGreen))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _taskStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: kGreen));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final active = docs
                      .where((d) => !['resolved', 'rejected'].contains(d.data()['status'] ?? ''))
                      .toList();
                  final resolved = docs
                      .where((d) => ['resolved', 'rejected'].contains(d.data()['status'] ?? ''))
                      .toList();

                  int byCreatedDesc(QueryDocumentSnapshot<Map<String, dynamic>> a,
                      QueryDocumentSnapshot<Map<String, dynamic>> b) {
                    final ta = a.data()['createdAt'];
                    final tb = b.data()['createdAt'];
                    if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                    return 0;
                  }

                  active.sort(byCreatedDesc);
                  resolved.sort(byCreatedDesc);

                  return TabBarView(
                    children: [
                      _taskList(active, emptyText: 'No active tasks right now'),
                      _taskList(resolved, emptyText: 'No resolved tasks yet'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _isLeader
            ? FloatingActionButton.extended(
          backgroundColor: kGreen,
          label: const Text('Add task', style: TextStyle(color: Colors.white)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTestTaskScreen()),
            );
          },
        )
            : null,
      ),
    );
  }

  Widget _taskList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {required String emptyText}) {
    if (docs.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.black45)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i].data();
        final taskId = docs[i].id;
        return _taskCard(context, taskId, data);
      },
    );
  }

  Widget _taskCard(BuildContext context, String taskId, Map<String, dynamic> data) {
    final String type = taskType(data);
    final String priority = resolvePriority(data);
    final String address = taskAddress(data);
    final String description = data['description'] ?? '';
    final String status = data['status'] ?? 'dispatched';

    final colors = priorityColors(priority);

    String timeAgo = '-';
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      final diff = DateTime.now().difference(createdAt.toDate());
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes} mins ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours} hr ago';
      } else {
        timeAgo = '${diff.inDays} days ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: colors[0], borderRadius: BorderRadius.circular(20)),
                child: Text('${priorityLabel(priority)} priority',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors[1])),
              ),
              Text(timeAgo, style: const TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
          const SizedBox(height: 8),
          Text(type, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45),
            const SizedBox(width: 4),
            Expanded(
                child: Text(address,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewTaskScreen(taskId: taskId)),
                );
              },
              child: Text(['resolved', 'rejected'].contains(status) ? 'View summary' : 'View details',
                  style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}