import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_disaster_management_system/database/citizen_dao.dart'; // adjust path if needed
import 'edit_profile_screen.dart';
import 'feedback_screen.dart';
import 'notification_settings_screen.dart';

// UI and menu actions are exactly the same as before. The only addition:
// the profile is shown instantly from the SQLite cache (works offline
// too), then silently refreshed + re-cached whenever the live Firestore
// stream has new data. Uses the SAME CitizenDao as the Home and Alerts
// screens — no new DAO needed here.
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic>? _profile;
  bool _loadedOnce = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) Show cache immediately — this works even with zero internet.
    final cached = await CitizenDao.getCachedProfile(_uid);
    if (cached != null && mounted) {
      setState(() {
        _profile = cached;
        _loadedOnce = true;
      });
    }

    // 2) Live Firestore stream — same document as the original
    // StreamBuilder, just now we cache the result and call setState
    // ourselves.
    _sub = FirebaseFirestore.instance
        .collection('citizens')
        .doc(_uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final name = (data['name'] ?? 'Not set').toString();
      final email = (data['email'] ?? 'Not set').toString();
      final phone = (data['phone'] ?? 'Not set').toString();
      final address = (data['address'] ?? 'Not set').toString();
      final emName = (data['emergencyContactName'] ?? '').toString();
      final emPhone = (data['emergencyContactPhone'] ?? '').toString();
      final emRelation = (data['emergencyContactRelation'] ?? '').toString();

      await CitizenDao.cacheProfile(
        uid: _uid,
        name: name,
        email: email,
        phone: phone,
        address: address,
        emergencyContactName: emName,
        emergencyContactPhone: emPhone,
        emergencyContactRelation: emRelation,
      );

      if (mounted) {
        setState(() {
          _profile = {
            'uid': _uid,
            'name': name,
            'email': email,
            'phone': phone,
            'address': address,
            'emergencyContactName': emName,
            'emergencyContactPhone': emPhone,
            'emergencyContactRelation': emRelation,
          };
          _loadedOnce = true;
        });
      }
    }, onError: (_) {
      // Offline — the cached profile is already showing, nothing to do here.
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'View Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              } else if (value == 'notifications') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              } else if (value == 'feedback') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeedbackScreen(),
                  ),
                );
              } else if (value == 'signout') {
                FirebaseAuth.instance.signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: _CustomMenuItem(
                  icon: Icons.edit,
                  text: 'Edit Profile',
                ),
              ),
              PopupMenuItem(
                value: 'notifications',
                child: _CustomMenuItem(
                  icon: Icons.notifications,
                  text: 'Notifications',
                ),
              ),
              PopupMenuItem(
                value: 'feedback',
                child: _CustomMenuItem(
                  icon: Icons.feedback,
                  text: 'Give Feedback',
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_loadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return const Center(child: Text('Unable to load profile.'));
    }

    final data = _profile!;
    final String name = data['name'] ?? 'Not set';
    final String email = data['email'] ?? 'Not set';
    final String phone = data['phone'] ?? 'Not set';
    final String address = data['address'] ?? 'Not set';

    final String emName = data['emergencyContactName'] ?? '';
    final String emPhone = data['emergencyContactPhone'] ?? '';
    final String emRelation = data['emergencyContactRelation'] ?? '';
    final bool hasEmergencyContact = emName.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey.shade300,
            child: const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 16),

          _sectionTitle('CONTACT INFORMATION'),
          const SizedBox(height: 12),

          _contactCard(
            icon: Icons.email,
            title: 'Email',
            subtitle: email,
            trailingIcon: Icons.lock,
          ),
          const SizedBox(height: 10),
          _contactCard(
            icon: Icons.phone,
            title: 'Phone Number',
            subtitle: phone,
          ),
          const SizedBox(height: 10),
          _contactCard(
            icon: Icons.location_on,
            title: 'Location',
            subtitle: address,
          ),

          const SizedBox(height: 24),

          _sectionTitle('EMERGENCY CONTACT'),
          const SizedBox(height: 12),

          hasEmergencyContact
              ? _emergencyContactCard(
            name: emName,
            phone: emPhone,
            relation: emRelation,
          )
              : _emptyEmergencyContactCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    IconData? trailingIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            child: Icon(icon, size: 20, color: Colors.black54),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, color: Colors.black38, size: 18),
        ],
      ),
    );
  }

  Widget _emergencyContactCard({
    required String name,
    required String phone,
    required String relation,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6D97A), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFF5D020),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF7B5800),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Relation: $relation',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone_in_talk, color: Colors.black54),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phone,
                  style: const TextStyle(fontSize: 14, letterSpacing: 1),
                ),
              ),
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF1B5E38),
                child: Icon(Icons.call, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyEmergencyContactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No emergency contact added yet. Tap Edit Profile to add one.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// Stateful Widget for Interactive Tap Highlight Effect
class _CustomMenuItem extends StatefulWidget {
  final IconData icon;
  final String text;

  const _CustomMenuItem({
    required this.icon,
    required this.text,
  });

  @override
  State<_CustomMenuItem> createState() => _CustomMenuItemState();
}

class _CustomMenuItemState extends State<_CustomMenuItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1B5E38);
    const inactiveColor = Colors.black87;

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      child: Row(
        children: [
          Icon(
            widget.icon,
            color: _isPressed ? activeColor : inactiveColor,
          ),
          const SizedBox(width: 12),
          Text(
            widget.text,
            style: TextStyle(
              color: _isPressed ? activeColor : inactiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}