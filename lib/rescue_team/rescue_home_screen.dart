import 'package:flutter/material.dart';
import 'view_task_screen.dart';
import 'view_profile_screen.dart';
import 'editprofilescreen.dart';
import 'profile_updated_screen.dart';

class RescueTask {
  final String type;
  final String location;
  final String timeAgo;
  const RescueTask({required this.type, required this.location, required this.timeAgo});
}
class RescueTeamHomeScreen extends StatefulWidget {
  const RescueTeamHomeScreen({super.key});
  @override
  State<RescueTeamHomeScreen> createState() => _RescueTeamHomeScreenState();
}
class _RescueTeamHomeScreenState extends State<RescueTeamHomeScreen> {
  int _selectedIndex = 0;

  static const Color kGreen    = Color(0xFF1E5631);
  static const Color kRed      = Color(0xFFD32F2F);
  static const Color kLightRed = Color(0xFFFFF0F0);
  static const Color kBg       = Color(0xFFF5F5F5);

  final List<RescueTask> _tasks = const [
    RescueTask(type: 'Earthquake', location: 'Mandi Bhauddin', timeAgo: '2 mins ago'),
    RescueTask(type: 'Flood',      location: 'Lahore',          timeAgo: '15 mins ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: _bottomNav(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 10),

                _topBar(),

                const SizedBox(height: 12),

                _alertCard(),

                const SizedBox(height: 14),

                SizedBox(
                  height: 220,
                  child: _riskMap(),
                ),

                const SizedBox(height: 14),

                _urgentTasks(),

                const SizedBox(height: 14),

                _actionButtons(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ── TOP BAR
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.menu, size: 24, color: Colors.black87),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Pakistan Rescue Team',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          Stack(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
              ),
              child: const Icon(Icons.notifications_outlined, size: 20, color: Colors.black87),
            ),
            Positioned(top: 5, right: 5,
                child: Container(width: 9, height: 9,
                    decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle))),
          ]),
        ],
      ),
    );
  }

  // ── ALERT CARD
  Widget _alertCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: kRed, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error, color: Colors.white, size: 12),
                  SizedBox(width: 3),
                  Text('HIGH ALERT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ]),
              ),
              const Text('5m ago', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 5),
          const Text('Monsoon Flooding',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 3),
          const Text(
            'Emergency protocols active across southern coastal belts. Immediate evacuations in progress.',
            style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  // ── RISK MAP
  Widget _riskMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Regional Risk Map',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'EXPAND',
                style: TextStyle(
                  color: kGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6A9EAE),
                        Color(0xFFB8C9A3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TopoPainter(),
                  ),
                ),
                Positioned(
                  left: 70,
                  top: 30,
                  child: _dot(Colors.red[900]!, 18),
                ),
                Positioned(
                  right: 90,
                  top: 45,
                  child: _dot(kRed, 13),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _chip('HQ Location'),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _chip('● Active Flooding'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color c, double sz) => Container(
    width: sz, height: sz,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 5, spreadRadius: 1)]),
  );

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
  );

  // ── URGENT TASKS
  Widget _urgentTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Urgent Rescue Tasks',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '12 ACTIVE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
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
  Widget _taskCard(RescueTask task) {
    final icon = task.type == 'Earthquake' ? Icons.warning_rounded : Icons.flood;
    return Container(
      decoration: BoxDecoration(color: kLightRed, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(height: 1),
            const Text('URGENT',
                style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
          ]),
        ),
        title: Text(task.type,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        subtitle: Text('${task.location} • ${task.timeAgo}',
            style: const TextStyle(color: Colors.black54, fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black45, size: 18),
        onTap: () {},
      ),
    );
  }

  // ── ACTION BUTTONS
  Widget _actionButtons() {
    return Column(
      children: [
        SizedBox(
          height: 62,
          child: _actionBtn(
            Icons.map_outlined,
            'View Affected Areas',
                () {},
          ),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 62,
          child: _actionBtn(
            Icons.update,
            'Update Rescue Status',
                () {},
          ),
        ),
      ],
    );
  }
  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          const Icon(Icons.chevron_right, color: Colors.white, size: 20),
        ]),
      ),
    );
  }

  // ── BOTTOM NAV
  Widget _bottomNav (BuildContext  context) {
    const items = [
      {'icon': Icons.home_rounded,        'label': 'Home'},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks'},
      {'icon': Icons.map_outlined,        'label': 'Map'},
      {'icon': Icons.person_outline,      'label': 'Profile'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = _selectedIndex == i;
              return GestureDetector(
                onTap: () {
                  if (i == 1) {
                    // Tasks trigger
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyTasksScreen()),
                    );
                  } else if (i == 3) {
                    // Profile trigger
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RescueProfileScreen()),
                    );
                  } else {
                    setState(() => _selectedIndex = i);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i]['icon'] as IconData, color: sel ? kGreen : Colors.grey, size: 22),
                    const SizedBox(height: 3),
                    Text(items[i]['label'] as String,
                        style: TextStyle(fontSize: 10,
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

class _TopoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final curves = [
      [0.3, 0.2, 0.6, 0.5, 0.9, 0.3],
      [0.1, 0.5, 0.4, 0.7, 0.8, 0.6],
      [0.2, 0.8, 0.5, 0.9, 0.95, 0.75],
      [0.0, 0.1, 0.3, 0.35, 0.7, 0.15],
    ];
    for (final c in curves) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * c[0], size.height * c[1])
          ..quadraticBezierTo(size.width * c[2], size.height * c[3], size.width * c[4], size.height * c[5]),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}