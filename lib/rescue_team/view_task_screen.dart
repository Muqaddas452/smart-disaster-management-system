import 'package:flutter/material.dart';

enum TaskPriority { high, medium, low }

class MyTask {
  final String title;
  final String location;
  final String description;
  final String timeAgo;
  final TaskPriority priority;

  const MyTask({
    required this.title,
    required this.location,
    required this.description,
    required this.timeAgo,
    required this.priority,
  });
}
// DUMMY DATA
const List<MyTask> kMyTasks = [
  MyTask(
    title: 'Flood Rescue',
    location: 'Sector 7 - Riverside Embankment',
    description:
    'Urgent extraction required for two civilians trapped on a residential rooftop. Water levels rising at 2cm/hr.',
    timeAgo: '10 mins ago',
    priority: TaskPriority.high,
  ),
  MyTask(
    title: 'Medical Escort',
    location: 'Point Bravo - Medical Triage Alpha',
    description:
    'Provide security and transport assistance for critical medical supplies arriving from the central depot.',
    timeAgo: '24 mins ago',
    priority: TaskPriority.medium,
  ),
  MyTask(
    title: 'Logistics Support',
    location: 'West Gateway - Staging Area',
    description:
    'Inventory check of emergency rations and water pallets at the west gateway distribution hub.',
    timeAgo: '1 hr ago',
    priority: TaskPriority.low,
  ),
];
// MY TASKS SCREEN

class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  static const Color kGreen = Color(0xFF1E5631);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: kMyTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) => _taskCard(context, kMyTasks[i]),
            ),
          ),
          _bottomNav(context),
        ],
      ),
    );
  }

  // ── TOP BAR
  Widget _topBar() {
    return Container(
      color: kGreen,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.menu, color: Colors.white, size: 26),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'MY TASKS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  // ── TASK CARD
  Widget _taskCard(BuildContext context, MyTask task) {
    final p = _priorityStyle(task.priority);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Priority badge + time
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: p.textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Text(
                  task.timeAgo,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),

          // ── Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              task.title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),

          const SizedBox(height: 6),

          // ── Location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(task.location,
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              task.description,
              style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
            ),
          ),

          const SizedBox(height: 14),

          // ── View Details button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'View Details',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PRIORITY STYLE HELPER
  _PriorityStyle _priorityStyle(TaskPriority p) => switch (p) {
    TaskPriority.high => _PriorityStyle(
      label: 'HIGH PRIORITY',
      bgColor: const Color(0xFFFFEBEE),
      textColor: const Color(0xFFD32F2F),
    ),
    TaskPriority.medium => _PriorityStyle(
      label: 'MEDIUM PRIORITY',
      bgColor: const Color(0xFFFFF8E1),
      textColor: const Color(0xFFE65100),
    ),
    TaskPriority.low => _PriorityStyle(
      label: 'LOW PRIORITY',
      bgColor: const Color(0xFFE3F2FD),
      textColor: const Color(0xFF1565C0),
    ),
  };

  // ── BOTTOM NAV
  Widget _bottomNav(BuildContext context) {
    const items = [
      {'icon': Icons.home_rounded,        'label': 'Home'},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks'},
      {'icon': Icons.map_outlined,        'label': 'Map'},
      {'icon': Icons.person_outline,      'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isTasks = i == 1;
              return GestureDetector(
                onTap: () {
                  if (i == 0) Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tasks tab — circular green bg
                    isTasks
                        ? Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(
                          color: kGreen, shape: BoxShape.circle),
                      child: Icon(items[i]['icon'] as IconData,
                          color: Colors.white, size: 24),
                    )
                        : Icon(items[i]['icon'] as IconData,
                        color: Colors.black54, size: 24),
                    const SizedBox(height: 3),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isTasks ? kGreen : Colors.black54,
                        fontWeight: isTasks ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── PRIORITY STYLE DATA CLASS
class _PriorityStyle {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _PriorityStyle({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}