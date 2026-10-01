import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_disaster_management_system/database/rescue_dao.dart'; // adjust path if needed

// --- Screen Imports ---
import 'view_task_screen.dart';
import 'tasks_list_screen.dart';
import 'member_status_list_screen.dart';
import 'leader_status_overview_screen.dart';
import 'team_leader/add_team_member.dart';
import 'mapscreen.dart';
import '../Services/map_service.dart';
import '../widgets/map/disaster_map.dart';

// Profile Imports
import 'team_leader/view_leader_profile_screen.dart';
import 'team_member/view_member_profile_screen.dart';

// UI, navigation, and map are exactly the same as before. The only
// addition: the alert banner and urgent tasks are shown instantly from
// the SQLite cache (works offline too), then silently refreshed +
// re-cached whenever the live Firestore stream has new data.
class RescueTeamHomeScreen extends StatefulWidget {
  final bool isLeader;
  final String teamId;
  final String teamName;

  const RescueTeamHomeScreen({
    super.key,
    this.isLeader = true,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<RescueTeamHomeScreen> createState() => _RescueTeamHomeScreenState();
}

class _RescueTeamHomeScreenState extends State<RescueTeamHomeScreen> {
  int _selectedIndex = 0;

  static const Color kGreen = Color(0xFF1E5631);
  static const Color kRed = Color(0xFFD32F2F);
  static const Color kLightRed = Color(0xFFFFF0F0);
  static const Color kBg = Color(0xFFF5F5F5);

  // ── Alert banner state (cache-first)
  Map<String, dynamic>? _liveAlert; // null = no active alert
  bool _alertLoadedOnce = false;
  StreamSubscription? _alertSub;

  // ── Urgent tasks state (cache-first)
  List<Map<String, dynamic>> _urgentTasks = [];
  bool _urgentLoadedOnce = false;
  StreamSubscription? _urgentSub;

  @override
  void initState() {
    super.initState();
    _initAlertSection();
    _initUrgentTasksSection();
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _urgentSub?.cancel();
    super.dispose();
  }

  Future<void> _initAlertSection() async {
    // 1) Show cache immediately — this works even with zero internet.
    final cached = await RescueDao.getCachedLiveAlert();
    if (cached != null && mounted) {
      setState(() {
        _liveAlert = cached;
        _alertLoadedOnce = true;
      });
    }

    // 2) Live Firestore stream — same source as the original StreamBuilder
    // (MapService.instance.getLatestActiveAlertDoc()), just now we cache
    // the result and call setState ourselves.
    _alertSub = MapService.instance.getLatestActiveAlertDoc().listen((snap) async {
      if (snap.docs.isEmpty) {
        await RescueDao.clearCachedLiveAlert();
        if (mounted) {
          setState(() {
            _liveAlert = null;
            _alertLoadedOnce = true;
          });
        }
        return;
      }

      final doc = snap.docs.first;
      final data = doc.data();
      final title = (data['title'] ?? 'Alert').toString();
      final message = (data['message'] ?? '').toString();
      final riskLevel = (data['riskLevel'] ?? 'Medium').toString();
      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      await RescueDao.cacheLiveAlert(
        title: title,
        message: message,
        riskLevel: riskLevel,
        latitude: lat,
        longitude: lng,
        createdAt: createdAt.toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _liveAlert = {
            'docId': doc.id,
            'title': title,
            'message': message,
            'riskLevel': riskLevel,
            'latitude': lat,
            'longitude': lng,
            'createdAt': createdAt.toIso8601String(),
            // keep the raw Firestore data + doc id around for the map,
            // which needs the full document shape, not just our cached
            // subset of fields.
            '_rawData': data,
            '_rawDocId': doc.id,
          };
          _alertLoadedOnce = true;
        });
      }
    }, onError: (_) {
      // Offline — the cached alert (if any) is already showing.
      if (mounted) setState(() => _alertLoadedOnce = true);
    });
  }

  void _initUrgentTasksSection() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _urgentLoadedOnce = true);
      return;
    }

    // 1) Show cache immediately — reads from the SAME cached_tasks table
    // that TasksListScreen already populates, filtered to high-priority,
    // not-yet-resolved tasks.
    RescueDao.getCachedUrgentTasks().then((cached) {
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _urgentTasks = cached;
          _urgentLoadedOnce = true;
        });
      }
    });

    // 2) Live Firestore stream — same query as the original StreamBuilder,
    // just now we upsert into cache (without wiping the full task list)
    // and call setState ourselves.
    final tasksRef = FirebaseFirestore.instance.collection('tasks');
    final Query<Map<String, dynamic>> query = widget.isLeader
        ? tasksRef.where('teamId', isEqualTo: widget.teamId).where('priority', isEqualTo: 'high')
        : tasksRef.where('assignedMemberIds', arrayContains: uid).where('priority', isEqualTo: 'high');

    _urgentSub = query.snapshots().listen((snap) async {
      final tasks = snap.docs.map((d) {
        final data = d.data();
        final createdAt = data['createdAt'];
        return {
          'taskId': d.id,
          'type': data['type'] ?? 'Task',
          'priority': data['priority'] ?? 'high',
          'address': data['address'] ?? 'Location unavailable',
          'description': data['description'] ?? '',
          'status': data['status'] ?? 'dispatched',
          'teamId': data['teamId'] ?? '',
          'assignedMemberIds': data['assignedMemberIds'] ?? [],
          'assignedMembers': data['assignedMembers'] ?? [],
          'latitude': (data['latitude'] as num?)?.toDouble(),
          'longitude': (data['longitude'] as num?)?.toDouble(),
          'createdAt': (createdAt is Timestamp) ? createdAt.toDate().toIso8601String() : '',
          'statusOverriddenBy': data['statusOverriddenBy'],
          'statusOverriddenAt': null,
        };
      }).toList();

      await RescueDao.upsertTasks(tasks);
      final activeUrgent = tasks.where((t) => (t['status'] ?? '') != 'resolved').toList();

      if (mounted) {
        setState(() {
          _urgentTasks = activeUrgent;
          _urgentLoadedOnce = true;
        });
      }
    }, onError: (_) {
      // Offline — the cached list is already showing, nothing to do here.
      if (mounted) setState(() => _urgentLoadedOnce = true);
    });
  }

  // Dynamic Navigation Items
  List<Map<String, dynamic>> _getNavItems() {
    return [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks'},
      if (widget.isLeader)
        {'icon': Icons.person_add_alt_1_rounded, 'label': 'Add Member'},
      {'icon': Icons.map_outlined, 'label': 'Map'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];
  }

  // Screens List for Navigation
  List<Widget> _getPages() {
    return [
      _buildHomeContent(),
      const TasksListScreen(),
      if (widget.isLeader)
        AddMemberScreen(
          teamId: widget.teamId,
          teamName: widget.teamName,
        ),
      const MapScreen(),
      widget.isLeader
          ? const RescueProfileScreen()
          : const ViewMemberProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: _bottomNav(context),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _getPages(),
        ),
      ),
    );
  }

  // ── HOME CONTENT (Pure Home View)
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _alertAndRiskMapSection(),
                const SizedBox(height: 14),
                _urgentTasksSection(),
                const SizedBox(height: 14),
                _actionButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. TOP BAR SECTION
  Widget _topBar() {
    return Container(
      color: kGreen,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'SDMS - Pak Rescue Teams',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Stack(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_outlined, size: 20, color: Colors.white),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. LIVE ALERT & RISK MAP (cache-first)
  Widget _alertAndRiskMapSection() {
    if (!_alertLoadedOnce) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    if (_liveAlert == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No active alerts right now.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      );
    }

    final data = _liveAlert!;
    final String title = data['title'] ?? 'Alert';
    final String message = data['message'] ?? '';
    final String riskLevel = data['riskLevel'] ?? 'Medium';
    final double lat = data['latitude'];
    final double lng = data['longitude'];
    final createdAtStr = data['createdAt']?.toString();
    final DateTime createdAt =
    (createdAtStr != null && createdAtStr.isNotEmpty)
        ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
        : DateTime.now();

    // The map needs the full raw Firestore document shape — only available
    // when this data came from the live stream (not from a cold cache-only
    // load before any internet has ever connected).
    final rawData = data['_rawData'] as Map<String, dynamic>?;
    final rawDocId = data['_rawDocId'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _alertCard(
          title: title,
          message: message,
          riskLevel: riskLevel,
          createdAt: createdAt,
          onTap: () {
            final navItems = _getNavItems();
            final mapIndex = navItems.indexWhere((item) => item['label'] == 'Map');
            if (mapIndex != -1) {
              setState(() => _selectedIndex = mapIndex);
            }
          },
        ),
        const SizedBox(height: 14),
        if (rawData != null && rawDocId != null)
          SizedBox(
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: DisasterMap(
                isAdmin: true,
                isRescueView: true,
                zonesStream: Stream.value(
                  [MapService.instance.alertDataToPolygon(rawData, rawDocId)],
                ),
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 11,
                ),
                autoFollowLocation: false,
                showControls: false,
              ),
            ),
          ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _alertCard({
    required String title,
    required String message,
    required String riskLevel,
    required DateTime createdAt,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: kRed, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          '${riskLevel.toUpperCase()} ALERT',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(_timeAgo(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(
                message,
                style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. URGENT TASKS (cache-first)
  Widget _urgentTasksSection() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    if (!_urgentLoadedOnce) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: kGreen)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Urgent Rescue Tasks',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_urgentTasks.length} ACTIVE',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_urgentTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No urgent tasks assigned currently.',
              style: TextStyle(color: Colors.black45, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.builder(
            itemCount: _urgentTasks.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final data = _urgentTasks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _taskCard(data['taskId'] as String, data),
              );
            },
          ),
      ],
    );
  }

  Widget _taskCard(String taskId, Map<String, dynamic> data) {
    final String type = data['type'] ?? 'Task';
    final String address = data['address'] ?? 'Location unavailable';

    String timeAgo = '-';
    final createdAtStr = data['createdAt']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final createdAt = DateTime.tryParse(createdAtStr);
      if (createdAt != null) timeAgo = _timeAgo(createdAt);
    }

    final IconData icon = type.toLowerCase().contains('earthquake')
        ? Icons.warning_rounded
        : Icons.flood;

    return Container(
      decoration: BoxDecoration(color: kLightRed, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(height: 1),
              const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        subtitle: Text('$address • $timeAgo', style: const TextStyle(color: Colors.black54, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black45, size: 18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewTaskScreen(taskId: taskId),
            ),
          );
        },
      ),
    );
  }

  // ── 4. ACTION BUTTONS
  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: _horizontalActionBtn(
            Icons.map_outlined,
            'View Affected Areas',
                () {
              final navItems = _getNavItems();
              final mapIndex = navItems.indexWhere((item) => item['label'] == 'Map');
              if (mapIndex != -1) {
                setState(() => _selectedIndex = mapIndex);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _horizontalActionBtn(
            Icons.update,
            'Update Rescue Status',
                () {
              // Member -> filtered "my tasks" list (existing ViewTaskScreen
              // buttons do the actual status update, unchanged).
              // Leader -> whole-team status overview + emergency override.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => widget.isLeader
                      ? LeaderStatusOverviewScreen(teamId: widget.teamId)
                      : const MemberStatusListScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _horizontalActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: kGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. FIXED BOTTOM NAVIGATION BAR
  Widget _bottomNav(BuildContext context) {
    final items = _getNavItems();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = _selectedIndex == i;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i]['icon'] as IconData,
                          color: sel ? kGreen : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i]['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: sel ? kGreen : Colors.grey,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}