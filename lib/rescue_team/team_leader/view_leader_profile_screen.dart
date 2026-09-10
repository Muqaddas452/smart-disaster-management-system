import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rescue_leader_personal_detail_screen.dart';
import 'rescue_leader_settings_screen.dart';
import '/citizen_screens/feedback_screen.dart';
import '/citizen_screens/feedback_success_screen.dart';

class RescueProfileScreen extends StatelessWidget {
  const RescueProfileScreen({super.key});

  static const Color kGreen = Color(0xFF1B5E38);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: uid == null
                ? const Center(child: Text('User not logged in'))
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rescueTeamUsers')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final data = snapshot.data?.data() ?? {};
                // If the name field is genuinely missing from Firestore (not just
                // still loading), fall back to something readable instead of a
                // permanent "Loading..." label.
                final String name = (data['name'] ?? '').toString().trim().isNotEmpty
                    ? data['name']
                    : 'Rescue Leader';
                final String email = data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _header(name, email)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: Column(
                          children: [
                            _menuTile(
                              context,
                              icon: Icons.person_outline,
                              title: 'Personal Details',
                              subtitle: 'View your & team profile information',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RescuePersonalDetailsScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _menuTile(
                              context,
                              icon: Icons.settings_outlined,
                              title: 'Settings',
                              subtitle: 'Edit profile & notification preferences',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RescueSettingsScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _menuTile(
                              context,
                              icon: Icons.feedback_outlined,
                              title: 'Feedback',
                              subtitle: 'Send your valuable feedback',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _menuTile(
                              context,
                              icon: Icons.logout,
                              title: 'Logout',
                              subtitle: 'Sign out from your account',
                              isDestructive: true,
                              onTap: () => _confirmLogout(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _bottomNav(context),
        ],
      ),
    );
  }

  // ── HEADER (avatar + name + email, rounded green card)
  Widget _header(String name, String email) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ── MENU TILE
  Widget _menuTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
        bool isDestructive = false,
      }) {
    final Color color = isDestructive ? Colors.red : Colors.black87;
    final Color iconBg = isDestructive ? Colors.red.withOpacity(0.08) : kGreen.withOpacity(0.08);
    final Color iconColor = isDestructive ? Colors.red : kGreen;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── LOGOUT (confirmation dialog → FirebaseAuth.signOut → back to root/splash)
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        // This only signs out the CURRENT device/account (leader or member,
        // whoever is logged in) — it never affects other team members or the
        // team's Firestore data. Popping to root lets the app's existing
        // auth-aware splash/routing detect the signed-out state and redirect
        // to the Welcome/Login screen.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // ── BOTTOM NAV
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final sel = i == 3;
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