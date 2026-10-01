import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_disaster_management_system/database/rescue_dao.dart'; // adjust path if needed
import 'rescue_leader_personal_detail_screen.dart';
import 'rescue_leader_settings_screen.dart';
import '/citizen_screens/feedback_screen.dart';
import '/citizen_screens/feedback_success_screen.dart';

// UI, menu, and logout logic are exactly the same as before. The only
// addition: the header (name/email/photo) is shown instantly from the
// SQLite cache (works offline too), then silently refreshed + re-cached
// whenever the live Firestore stream has new data.
class RescueProfileScreen extends StatefulWidget {
  const RescueProfileScreen({super.key});

  @override
  State<RescueProfileScreen> createState() => _RescueProfileScreenState();
}

class _RescueProfileScreenState extends State<RescueProfileScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  String _name = 'Rescue Leader';
  String _email = '';
  String? _photoUrl;
  bool _loadedOnce = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadedOnce = true);
      return;
    }

    // 1) Show cache immediately — this works even with zero internet.
    final cached = await RescueDao.getCachedProfile(uid);
    if (cached != null && mounted) {
      final cachedName = (cached['name'] ?? '').toString().trim();
      setState(() {
        _name = cachedName.isNotEmpty ? cachedName : 'Rescue Leader';
        _email = (cached['email'] ?? '').toString();
        _photoUrl = (cached['photoUrl'] ?? '').toString();
        _loadedOnce = true;
      });
    }

    // 2) Live Firestore stream — same document as the original
    // StreamBuilder, just now we cache the result and call setState
    // ourselves.
    _sub = FirebaseFirestore.instance
        .collection('rescueTeamUsers')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      final data = snap.data() ?? {};
      final name = (data['name'] ?? '').toString().trim().isNotEmpty
          ? data['name'].toString()
          : 'Rescue Leader';
      final email = (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();
      final photoUrl = (data['photoUrl'] ?? '').toString();

      // We only own the header fields here — the full profile (specialization,
      // blood group, etc.) is cached by RescuePersonalDetailsScreen. To avoid
      // overwriting those fields with blanks, read what's cached first and
      // merge just the header fields into it.
      final existing = await RescueDao.getCachedProfile(uid);
      await RescueDao.cacheProfile(
        uid: uid,
        name: name,
        email: email,
        phone: (existing?['phone'] ?? '').toString(),
        emergencyContact: (existing?['emergencyContact'] ?? '').toString(),
        personalAddress: (existing?['personalAddress'] ?? '').toString(),
        specialization: (existing?['specialization'] ?? '').toString(),
        bloodGroup: (existing?['bloodGroup'] ?? '').toString(),
        teamName: (existing?['teamName'] ?? '').toString(),
        teamId: (existing?['teamId'] ?? '').toString(),
        officialAddress: (existing?['officialAddress'] ?? '').toString(),
        role: (existing?['role'] ?? 'rescue_leader').toString(),
        isLeader: true,
        photoUrl: photoUrl,
        createdAt: (existing?['createdAt'] ?? '').toString(),
      );

      if (mounted) {
        setState(() {
          _name = name;
          _email = email;
          _photoUrl = photoUrl;
          _loadedOnce = true;
        });
      }
    }, onError: (_) {
      // Offline — the cached header is already showing, nothing to do here.
      if (mounted) setState(() => _loadedOnce = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: uid == null
                ? const Center(child: Text('User not logged in'))
                : !_loadedOnce
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(_name, _email, _photoUrl)),
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
                            MaterialPageRoute(builder: (_) => const RescueSettingsScreen(isLeader: true)),
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
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER (avatar + name + email, rounded green card)
  Widget _header(String name, String email, String? photoUrl) {
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
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white24,
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
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
      // Mark offline BEFORE signing out — once signed out we lose permission
      // to write this doc, and currentUser becomes null.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).update({
            'isOnline': false,
            'lastSeenAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // Non-critical — don't block logout if this write fails.
        }
      }
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
}