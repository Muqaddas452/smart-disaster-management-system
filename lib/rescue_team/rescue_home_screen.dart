import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// --- Screen Imports ---
import 'view_task_screen.dart';
import 'tasks_list_screen.dart';
import 'team_leader/view_leader_profile_screen.dart';
import 'team_leader/editprofilescreen.dart';
import 'profile_updated_screen.dart';
import 'team_leader/add_team_member.dart'; // Import for adding team members (Leader role)
import 'mapscreen.dart'; // Import for the shared Affected Zones / Tasks map screen
import '../Services/map_service.dart';
import '../widgets/map/disaster_map.dart';

/// Data model representing a single rescue task
class RescueTask {
  final String type;
  final String location;
  final String timeAgo;

  const RescueTask({
    required this.type,
    required this.location,
    required this.timeAgo,
  });
}

/// Rescue Team Home Screen Widget
class RescueTeamHomeScreen extends StatefulWidget {
  // Flag to determine if the user is a team leader or a regular member
  final bool isLeader;

  // Dynamic fields for Firestore/Backend integration
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
  // Track selected tab index in the bottom navigation bar
  int _selectedIndex = 0;

  // App Theme Color Palette
  static const Color kGreen = Color(0xFF1E5631); // Dark Green (Header & Primary Buttons)
  static const Color kRed = Color(0xFFD32F2F); // High Alert / Urgent Accent Color
  static const Color kLightRed = Color(0xFFFFF0F0); // Background Tint for High-Priority Tasks
  static const Color kBg = Color(0xFFF5F5F5); // Screen Canvas Background Color

  // Mock List of Active Rescue Tasks
  final List<RescueTask> _tasks = const [
    RescueTask(type: 'Earthquake', location: 'Mandi Bhauddin', timeAgo: '2 mins ago'),
    RescueTask(type: 'Flood', location: 'Lahore', timeAgo: '15 mins ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      // Dynamic Bottom Navigation Bar
      bottomNavigationBar: _bottomNav(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar / App Header Section
              _topBar(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 2 & 3. Live Alert Card + Regional Risk Mini-Map
                    // (both come from the SAME latest broadcast_alerts doc)
                    _alertAndRiskMapSection(),

                    const SizedBox(height: 14),

                    // 4. Urgent Rescue Tasks Section
                    _urgentTasks(),

                    const SizedBox(height: 14),

                    // 5. Action Buttons (Horizontal Layout)
                    _actionButtons(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. TOP BAR SECTION
  // Renders header bar with custom dark green theme styling
  Widget _topBar() {
    return Container(
      color: kGreen, // Dark Green Header Bar
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Navigation Drawer Icon
          const Icon(Icons.menu, size: 24, color: Colors.white),
          const SizedBox(width: 12),

          // Header Title
          const Expanded(
            child: Text(
              'Pakistan Rescue Team',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // Notification Bell Container with Red Indicator Badge
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
              // Unread Notification Dot Indicator
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

  // ── 2 & 3. LIVE ALERT CARD + RISK MAP SECTION
  // Streams the latest active broadcast_alerts doc once and uses
  // it to render BOTH the compact alert card and the mini map
  // centered on that alert's location — so they always agree.
  Widget _alertAndRiskMapSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: MapService.instance.getLatestActiveAlertDoc(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data!.docs.isEmpty) {
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

        final doc = snapshot.data!.docs.first;
        final data = doc.data();

        final String title = (data['title'] ?? 'Alert').toString();
        final String message = (data['message'] ?? '').toString();
        final String riskLevel = (data['riskLevel'] ?? 'Medium').toString();
        final double lat = (data['latitude'] as num).toDouble();
        final double lng = (data['longitude'] as num).toDouble();
        final DateTime createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _alertCard(
              title: title,
              message: message,
              riskLevel: riskLevel,
              createdAt: createdAt,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DisasterMap(
                  isAdmin: true, // hides citizen-style banner clutter
                  isRescueView: true,
                  zonesStream: Stream.value(
                    [MapService.instance.alertDataToPolygon(data, doc.id)],
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
      },
    );
  }

  // Helper: relative time text ("5m ago", "2h ago"...)
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── 2. HIGH ALERT BANNER CARD
  // Displays the latest active broadcast alert in a compact layout
  Widget _alertCard({
    required String title,
    required String message,
    required String riskLevel,
    required DateTime createdAt,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: kRed, width: 4)), // Left accent bar
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alert Badge Tag & Relative Timestamp
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
              Text(_timeAgo(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),

          const SizedBox(height: 4),

          // Alert Main Heading
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          ),

          const SizedBox(height: 2),

          // Truncated Description Line
          Text(
            message,
            style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 4. URGENT TASKS LIST SECTION
  Widget _urgentTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title Bar with Active Task Counter Badge
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
              child: const Text(
                '12 ACTIVE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Task Item List Builder
        ListView.builder(
          itemCount: _tasks.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _taskCard(_tasks[index]),
            );
          },
        ),
      ],
    );
  }

  // Helper Widget: Individual Task List Item
  Widget _taskCard(RescueTask task) {
    final icon = task.type == 'Earthquake' ? Icons.warning_rounded : Icons.flood;
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
        title: Text(task.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        subtitle: Text('${task.location} • ${task.timeAgo}', style: const TextStyle(color: Colors.black54, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black45, size: 18),
        onTap: () {},
      ),
    );
  }

  // ── 5. ACTION BUTTONS SECTION (HORIZONTAL LAYOUT)
  Widget _actionButtons() {
    return Row(
      children: [
        // Primary Action 1: View Affected Areas Map
        Expanded(
          child: _horizontalActionBtn(
            Icons.map_outlined,
            'View Affected Areas',
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),

        // Primary Action 2: Update Operations Status
        Expanded(
          child: _horizontalActionBtn(
            Icons.update,
            'Update Rescue Status',
                () {},
          ),
        ),
      ],
    );
  }

  // Helper Widget: Reusable Horizontal Action Button
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

  // ── 6. BOTTOM NAVIGATION BAR SECTION
  // Renders navigation items dynamically and conditionally displays "Add Member" for leaders
  Widget _bottomNav(BuildContext context) {
    // Dynamic List of Navigation Elements
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks'},
      // Append "Add Member" option only when widget.isLeader is true
      if (widget.isLeader)
        {'icon': Icons.person_add_alt_1_rounded, 'label': 'Add Member'},
      {'icon': Icons.map_outlined, 'label': 'Map'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = _selectedIndex == i;
              final label = items[i]['label'] as String;

              return GestureDetector(
                onTap: () {
                  // Navigation Routing Handler Logic
                  if (label == 'Tasks') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TasksListScreen()),
                    );
                  } else if (label == 'Add Member') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddMemberScreen(
                          teamId: widget.teamId,     // Dynamic teamId forwarded from state
                          teamName: widget.teamName, // Dynamic teamName forwarded from state
                        ),
                      ),
                    );
                  } else if (label == 'Profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RescueProfileScreen()),
                    );
                  } else if (label == 'Map') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    );
                  } else {
                    setState(() => _selectedIndex = i);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i]['icon'] as IconData,
                        color: sel ? kGreen : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: sel ? kGreen : Colors.grey,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
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