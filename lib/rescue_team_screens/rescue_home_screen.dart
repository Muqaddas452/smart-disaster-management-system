import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// --- Screen Imports ---
import 'view_task_screen.dart';
import 'tasks_list_screen.dart';
import 'package:smartdisaster/rescue_team_screens/team_member/member_status_list_screen.dart';
import 'package:smartdisaster/rescue_team_screens/team_leader/leader_status_overview_screen.dart';
import 'team_leader/add_team_member.dart';
import 'package:smartdisaster/rescue_team_screens/rescue_map_screen.dart';
import 'package:smartdisaster/services/map_service.dart';
import 'package:smartdisaster/models/polygon_model.dart';
import 'package:smartdisaster/utils/priority_helper.dart';
import 'package:smartdisaster/services/fcm_token_service.dart';
import 'package:smartdisaster/widgets/map/disaster_map.dart';
import 'package:smartdisaster/database/rescue_dao.dart';
import 'package:smartdisaster/database/db_Helper.dart';

// Profile Imports
import 'team_leader/view_leader_profile_screen.dart';
import 'team_member/view_member_profile_screen.dart';

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

class _RescueTeamHomeScreenState extends State<RescueTeamHomeScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isOffline = false;

  static const Color kGreen = Color(0xFF1E5631);
  static const Color kRed = Color(0xFFD32F2F);
  static const Color kLightRed = Color(0xFFFFF0F0);
  static const Color kBg = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    // Leader/member ka token har dafa taza save (reopen, token refresh) —
    // taake app band hone par bhi task notifications milen.
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      FcmTokenService.saveFCMToken(myUid, collection: 'rescueTeamUsers');
      FcmTokenService.listenForTokenRefresh(myUid, collection: 'rescueTeamUsers');
    }
    _checkConnectivity();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
      if (mounted && _isOffline != offline) {
        setState(() => _isOffline = offline);
      }
    });
  }

  // Online/offline chip sahi rakhne ke liye: app background mein jaye to offline.
  void _setOnline(bool online) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('rescueTeamUsers')
        .doc(uid)
        .set({'isOnline': online}, SetOptions(merge: true))
        .catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnline(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = results.contains(ConnectivityResult.none));
    }
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
        child: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.amber.shade800,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.offline_bolt, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Offline Mode — Viewing Cached Data',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _getPages(),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                // Purane broadcast "High Priority Alerts" ki list home se hata di:
                // ab sirf active High task / zone (upar) aur Urgent tasks dikhte hain.
                _urgentTasks(),
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
          if (_isOffline)
            const Icon(Icons.cloud_off, color: Colors.white70, size: 18),
        ],
      ),
    );
  }

  // Home par SIRF High priority dikhta hai (medium/low nahi):
  //  1) is user ke active HIGH tasks (citizen report ya admin ke manual task), warna
  //  2) active HIGH affected zone, warna
  //  3) "koi high alert nahi".
  Widget _alertAndRiskMapSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>?>(
      stream: MapService.instance.getLatestActiveAlertDoc(),
      builder: (context, zoneSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _myTasksQuery()?.snapshots(),
          builder: (context, taskSnap) {
            if (!zoneSnap.hasData && !taskSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: kGreen)),
              );
            }

            final highTasks = (taskSnap.data?.docs ?? []).where((d) =>
            !['resolved', 'rejected'].contains(d.data()['status'] ?? '') &&
                isHighPriority(d.data())).toList()
              ..sort((a, b) {
                final ta = a.data()['createdAt'];
                final tb = b.data()['createdAt'];
                if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
                return 0;
              });

            final highZones = (zoneSnap.data?.docs ?? []).where((d) {
              final st = (d.data()['status'] ?? '').toString().toLowerCase();
              return !['resolved', 'inactive', 'closed', 'ended'].contains(st) &&
                  isHighPriority(d.data());
            }).toList();

            if (highTasks.isEmpty && highZones.isEmpty) {
              // Koi active High alert nahi — message ke saath map phir bhi dikhta rahe
              // (user ki apni location par).
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No active high priority alerts right now.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: DisasterMap(
                        isAdmin: true,
                        isRescueView: true,
                        zonesStream: Stream.value(<PolygonModel>[]),
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(30.3753, 69.3451),
                          zoom: 5,
                        ),
                        autoFollowLocation: true,
                        showControls: true,
                      ),
                    ),
                  ),
                ],
              );
            }

            final bool fromTask = highTasks.isNotEmpty;
            final doc = fromTask ? highTasks.first : highZones.first;
            final data = doc.data();

            String title;
            String message;
            double lat;
            double lng;
            List<PolygonModel> polygons;

            if (fromTask) {
              title = taskType(data);
              message = (data['description'] ?? '').toString().trim().isNotEmpty
                  ? data['description'].toString()
                  : taskAddress(data, fallback: '');
              lat = ((data['latitude'] ?? data['lat']) as num?)?.toDouble() ?? 30.3753;
              lng = ((data['longitude'] ?? data['lng']) as num?)?.toDouble() ?? 69.3451;
              polygons = <PolygonModel>[];
            } else {
              final String disasterType = (data['disasterType'] ?? '').toString().trim();
              title = (data['title'] ?? data['type'] ?? '').toString().trim().isNotEmpty
                  ? (data['title'] ?? data['type']).toString()
                  : (disasterType.isNotEmpty ? '$disasterType Alert' : 'Alert');
              message = (data['message'] ?? data['description'] ?? data['zoneName'] ?? '')
                  .toString();
              final poly = MapService.instance.alertDataToPolygon(data, doc.id);
              polygons = [poly];
              lat = ((data['latitude'] ?? data['lat']) as num?)?.toDouble() ??
                  (poly.coordinates.isNotEmpty ? poly.coordinates.first.latitude : 30.3753);
              lng = ((data['longitude'] ?? data['lng']) as num?)?.toDouble() ??
                  (poly.coordinates.isNotEmpty ? poly.coordinates.first.longitude : 69.3451);
            }
            final DateTime createdAt =
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _alertCard(
                  title: title,
                  message: message,
                  riskLevel: 'High',
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
                SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: DisasterMap(
                      isAdmin: true,
                      isRescueView: true,
                      zonesStream: Stream.value(polygons),
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
          },
        );
      },
    );
  }

  /// Is user ke tasks ki query (leader: team ke sab, member: apne assigned).
  Query<Map<String, dynamic>>? _myTasksQuery() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final tasksRef = FirebaseFirestore.instance.collection('tasks');
    return widget.isLeader
        ? tasksRef.where('teamId', isEqualTo: widget.teamId)
        : tasksRef.where('assignedMemberIds', arrayContains: uid);
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

  // Admin ke bheje HIGH priority alerts (broadcast_alerts) — leader aur member
  // dono ki home par. Priority admin ne jo rakhi wohi dikhti hai.
  // ignore: unused_element
  Widget _highPriorityAlerts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('broadcast_alerts').limit(40).snapshots(),
      builder: (context, snapshot) {
        final all = snapshot.data?.docs ?? [];
        final high = all.where((d) => isHighPriority(d.data())).toList();

        DateTime timeOf(Map<String, dynamic> m) {
          final t = m['createdAt'] ?? m['time'];
          if (t is Timestamp) return t.toDate();
          if (t is String) return DateTime.tryParse(t) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        high.sort((a, b) => timeOf(b.data()).compareTo(timeOf(a.data())));
        if (high.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'High Priority Alerts',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${high.length} HIGH',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...high.take(3).map((d) {
                final m = d.data();
                final String title = (m['title'] ?? m['disaster'] ?? m['disasterType'] ?? 'Emergency Alert').toString();
                final String area = (m['targetArea'] ?? m['district'] ?? m['city'] ?? '').toString();
                final String message = (m['message'] ?? '').toString();
                final DateTime t = timeOf(m);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _alertCard(
                    title: area.isEmpty ? title : '$title • $area',
                    message: message,
                    riskLevel: 'High',
                    createdAt: t.millisecondsSinceEpoch == 0 ? DateTime.now() : t,
                    onTap: () {
                      final navItems = _getNavItems();
                      final mapIndex = navItems.indexWhere((item) => item['label'] == 'Map');
                      if (mapIndex != -1) setState(() => _selectedIndex = mapIndex);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _urgentTasks() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    // priority ka filter ab client par (shared helper se) hota hai — pehle
    // Firestore mein exact 'high' match hota tha, jis se "High"/"HIGH" ya
    // severity_level mein likhi priority wale tasks kabhi nahi aate the.
    final tasksRef = FirebaseFirestore.instance.collection('tasks');
    final Query<Map<String, dynamic>> query = widget.isLeader
        ? tasksRef.where('teamId', isEqualTo: widget.teamId)
        : tasksRef.where('assignedMemberIds', arrayContains: uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: kGreen)),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final activeUrgentDocs = docs
            .where((d) =>
        !['resolved', 'rejected'].contains(d.data()['status'] ?? '') &&
            isHighPriority(d.data()))
            .toList();

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
                    '${activeUrgentDocs.length} ACTIVE',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activeUrgentDocs.isEmpty)
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
                itemCount: activeUrgentDocs.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final doc = activeUrgentDocs[index];
                  final data = doc.data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _taskCard(doc.id, data),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _taskCard(String taskId, Map<String, dynamic> data) {
    final String type = taskType(data);
    final String address = taskAddress(data, fallback: 'Location unavailable');

    String timeAgo = '-';
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      timeAgo = _timeAgo(createdAt.toDate());
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