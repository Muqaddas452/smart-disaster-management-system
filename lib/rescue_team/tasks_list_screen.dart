import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_disaster_management_system/database/rescue_dao.dart'; // adjust path if needed
import 'view_task_screen.dart';
import 'add_test_task_screen.dart'; // DEBUG ONLY — remove this import + FAB before final submission

// Shared "My Tasks" screen for BOTH leader and member. UI, tabs, and the
// leader/member query split are all exactly the same as before. The only
// addition: the task list is shown instantly from the SQLite cache (works
// offline too), then silently refreshed + re-cached whenever the live
// Firestore stream has new data. Role/teamId also fall back to the cached
// profile if the initial lookup fails while offline.
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

  List<Map<String, dynamic>> _tasks = [];
  bool _tasksLoadedOnce = false;
  StreamSubscription? _tasksSub;

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

    try {
      final doc = await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).get();
      final data = doc.data() ?? {};
      _teamId = data['teamId'];
      final role = data['role'] ?? '';
      _isLeader = data['isLeader'] == true || role == 'rescue_leader' || role == 'team_leader';
    } catch (_) {
      // Offline and no local Firestore cache for this doc — fall back to
      // our own SQLite cache of the profile so the correct query still runs.
      final cachedProfile = await RescueDao.getCachedProfile(uid);
      if (cachedProfile != null) {
        _teamId = cachedProfile['teamId'];
        _isLeader = cachedProfile['isLeader'] == 1;
      }
    }

    if (mounted) setState(() => _isLoading = false);
    _startTaskListening();
  }

  void _startTaskListening() {
    // 1) Show cached tasks immediately — works offline too.
    RescueDao.getCachedTasks().then((cached) {
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _tasks = cached;
          _tasksLoadedOnce = true;
        });
      }
    });

    // 2) Live Firestore stream — same query as before, just now we cache
    // the results and call setState ourselves.
    final tasksRef = FirebaseFirestore.instance.collection('tasks');
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream = _isLeader
        ? tasksRef.where('teamId', isEqualTo: _teamId).snapshots()
        : tasksRef.where('assignedMemberIds', arrayContains: _uid).snapshots();

    _tasksSub = stream.listen((snap) async {
      final tasks = snap.docs.map((d) {
        final data = d.data();
        final createdAt = data['createdAt'];
        return {
          'taskId': d.id,
          'type': data['type'] ?? 'Task',
          'priority': (data['priority'] ?? 'medium').toString(),
          'address': data['address'] ?? 'Address not available',
          'description': data['description'] ?? '',
          'status': data['status'] ?? 'dispatched',
          'teamId': data['teamId'] ?? '',
          'assignedMemberIds': data['assignedMemberIds'] ?? [],
          'assignedMembers': data['assignedMembers'] ?? [],
          'latitude': (data['latitude'] as num?)?.toDouble(),
          'longitude': (data['longitude'] as num?)?.toDouble(),
          'createdAt': (createdAt is Timestamp) ? createdAt.toDate().toIso8601String() : '',
          'statusOverriddenBy': data['statusOverriddenBy'],
          'statusOverriddenAt': (data['statusOverriddenAt'] is Timestamp)
              ? (data['statusOverriddenAt'] as Timestamp).toDate().toIso8601String()
              : null,
        };
      }).toList();

      await RescueDao.cacheTasks(tasks);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _tasksLoadedOnce = true;
        });
      }
    }, onError: (_) {
      // Offline — the cached list is already showing, nothing to do here.
      if (mounted) setState(() => _tasksLoadedOnce = true);
    });
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    super.dispose();
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
                          const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
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
                  : !_tasksLoadedOnce
                  ? const Center(child: CircularProgressIndicator(color: kGreen))
                  : Builder(builder: (context) {
                // "Resolved" tab = anything closed out, whether completed
                // or rejected by the leader — neither needs further action.
                final active = _tasks
                    .where((d) => !['resolved', 'rejected'].contains(d['status'] ?? ''))
                    .toList();
                final resolved = _tasks
                    .where((d) => ['resolved', 'rejected'].contains(d['status'] ?? ''))
                    .toList();

                // Newest first
                int byCreatedDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
                  final ta = a['createdAt']?.toString() ?? '';
                  final tb = b['createdAt']?.toString() ?? '';
                  return tb.compareTo(ta);
                }
                active.sort(byCreatedDesc);
                resolved.sort(byCreatedDesc);

                return TabBarView(
                  children: [
                    _taskList(active, emptyText: 'No active tasks right now'),
                    _taskList(resolved, emptyText: 'No resolved tasks yet'),
                  ],
                );
              }),
            ),
          ],
        ),
        bottomNavigationBar: _bottomNav(context),
        // DEBUG ONLY — remove this floatingActionButton before final submission
        floatingActionButton: _isLeader
            ? FloatingActionButton.extended(
          backgroundColor: kGreen,
          icon: const Icon(Icons.bug_report_outlined, color: Colors.white),
          label: const Text('Add test task', style: TextStyle(color: Colors.white)),
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

  Widget _taskList(List<Map<String, dynamic>> docs, {required String emptyText}) {
    if (docs.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.black45)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i];
        final taskId = data['taskId'] as String;
        return _taskCard(context, taskId, data);
      },
    );
  }

  Widget _taskCard(BuildContext context, String taskId, Map<String, dynamic> data) {
    final String type = data['type'] ?? 'Task';
    final String priority = (data['priority'] ?? 'medium').toString().toLowerCase();
    final String address = data['address'] ?? 'Address not available';
    final String description = data['description'] ?? '';
    final String status = data['status'] ?? 'dispatched';

    final priorityColors = {
      'high': const [Color(0xFFFCEBEB), Color(0xFF791F1F)],
      'medium': const [Color(0xFFFAEEDA), Color(0xFF633806)],
      'low': const [Color(0xFFE6F1FB), Color(0xFF042C53)],
    };
    final colors = priorityColors[priority] ?? priorityColors['medium']!;

    String timeAgo = '-';
    final createdAtStr = data['createdAt']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt != null) {
        final diff = DateTime.now().difference(createdAt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes} mins ago';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours} hr ago';
        } else {
          timeAgo = '${diff.inDays} days ago';
        }
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
                child: Text('${priority[0].toUpperCase()}${priority.substring(1)} priority',
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

  Widget _bottomNav(BuildContext context) {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks'},
      {'icon': Icons.map_outlined, 'label': 'Map'},
      {'icon': Icons.person, 'label': 'Profile'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = i == 1;
              return GestureDetector(
                onTap: () {
                  if (i == 0) Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i]['icon'] as IconData, color: sel ? kGreen : Colors.grey, size: 22),
                    const SizedBox(height: 3),
                    Text(items[i]['label'] as String,
                        style: TextStyle(
                            fontSize: 10,
                            color: sel ? kGreen : Colors.grey,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}