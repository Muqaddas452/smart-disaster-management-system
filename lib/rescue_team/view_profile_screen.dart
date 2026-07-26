import 'package:flutter/material.dart';
import 'editprofilescreen.dart';

class RescueProfileScreen extends StatelessWidget {
  const RescueProfileScreen({super.key});

  static const Color kGreen     = Color(0xFF1E5631);
  static const Color kLightBlue = Color(0xFFE8F4FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Dark green top bar
          _topBar(context),

          // ── Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _avatar(),
                  const SizedBox(height: 16),
                  _nameSection(),
                  const SizedBox(height: 28),
                  _sectionLabel('CONTACT INFORMATION'),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      _infoTile(Icons.email_outlined,    'EMAIL',         'ahmed.khan@alpha-rescue.org', trailing: Icons.lock_outline),
                      const SizedBox(height: 10),
                      _infoTile(Icons.phone_outlined,    'PHONE NUMBER',  '+1 (555) 902-3412'),
                      const SizedBox(height: 10),
                      _infoTile(Icons.location_on_outlined, 'BASE LOCATION', 'Alpha HQ, North Sector'),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('TEAM DETAILS'),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      _infoTile(Icons.group_outlined, 'CURRENT TEAM', 'Alpha Unit Core'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _infoTile(Icons.tag, 'BADGE ID', '#AUC-772', boldValue: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _infoTile(Icons.calendar_today_outlined, 'JOINED DATE', '12 May 2019', boldValue: true)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // ── Bottom nav
          _bottomNav(context),
        ],
      ),
    );
  }

  // ── TOP BAR
  Widget _topBar(BuildContext context) {
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
                child: Text('View Profile',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.settings_outlined, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  // ── AVATAR
  Widget _avatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [Color(0xFF76FF03), Color(0xFF1E5631), Color(0xFF76FF03)],
            ),
          ),
        ),
        // White gap
        Container(
          width: 122, height: 122,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
        // Avatar image placeholder
        Container(
          width: 114, height: 114,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2C3E50),
          ),
          clipBehavior: Clip.antiAlias,
          child: const Icon(Icons.person, size: 70, color: Colors.white54),
        ),
        // Green checkmark badge
        Positioned(
          bottom: 4, right: 4,
          child: Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
            child: const Icon(Icons.check, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  // ── NAME SECTION
  Widget _nameSection() {
    return Column(children: [
      const Text('Ahmed Ali Khan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 6),
      const Text('SENIOR RESCUER  •  ALPHA UNIT CORE',
          style: TextStyle(fontSize: 11, color: Colors.black45, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
    ]);
  }

  // ── SECTION LABEL
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: Colors.black45, letterSpacing: 1.4)),
      ),
    );
  }

  // ── INFO TILE
  Widget _infoTile(IconData icon, String label, String value,
      {IconData? trailing, bool boldValue = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kLightBlue),
            child: Icon(icon, size: 20, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          // Label + value
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.black45,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: boldValue ? FontWeight.bold : FontWeight.normal)),
            ]),
          ),
          // Optional trailing icon
          if (trailing != null)
            Icon(trailing, size: 20, color: Colors.black38),
        ],
      ),
    );
  }

  // ── BOTTOM NAV
  Widget _bottomNav(BuildContext context) {
    const items = [
      {'icon': Icons.home_rounded,        'label': 'Home'},
      {'icon': Icons.assignment_outlined, 'label': 'Tasks'},
      {'icon': Icons.map_outlined,        'label': 'Map'},
      {'icon': Icons.person,              'label': 'Profile'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
            blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = i == 3; // Profile active
              return GestureDetector(
                onTap: () {
                  if (i == 0) Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i]['icon'] as IconData,
                        color: sel ? kGreen : Colors.grey, size: 22),
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