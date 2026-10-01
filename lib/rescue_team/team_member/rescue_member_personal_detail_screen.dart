import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_disaster_management_system/database/rescue_dao.dart'; // adjust path if needed

// UI, team-name resolution, and the "incomplete profile" banner are all
// exactly the same as before. The only addition: details are shown
// instantly from the SQLite cache (works offline too), then silently
// refreshed + re-cached whenever the live Firestore stream has new data.
class RescueMemberPersonalDetailsScreen extends StatefulWidget {
  const RescueMemberPersonalDetailsScreen({super.key});

  @override
  State<RescueMemberPersonalDetailsScreen> createState() =>
      _RescueMemberPersonalDetailsScreenState();
}

class _RescueMemberPersonalDetailsScreenState
    extends State<RescueMemberPersonalDetailsScreen> {
  static const Color kGreen = Color(0xFF1B5E38);
  static const Color kLightBlue = Color(0xFFE8F4FD);

  Map<String, dynamic>? _profile;
  bool _loadedOnce = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Resolve team name from Firestore teams collection if missing in user doc
  // (unchanged logic — just kept as a static helper like before)
  static Future<String> _resolveTeamName(String userDocTeamName, String teamId) async {
    if (userDocTeamName.trim().isNotEmpty && userDocTeamName != '-') {
      return userDocTeamName;
    }
    if (teamId.isEmpty || teamId == '-') {
      return '-';
    }
    try {
      final teamDoc = await FirebaseFirestore.instance.collection('rescueTeams').doc(teamId).get();
      if (teamDoc.exists && teamDoc.data() != null) {
        return teamDoc.data()!['teamName'] ?? teamDoc.data()!['name'] ?? '-';
      }
    } catch (_) {}
    return '-';
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadedOnce = true);
      return;
    }

    // 1) Show cache immediately — this works even with zero internet.
    // Note: the cached teamName here is already the RESOLVED name (we
    // save it that way below), so no extra lookup is needed offline.
    final cached = await RescueDao.getCachedProfile(uid);
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
        .collection('rescueTeamUsers')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data() ?? {};

      final name = (data['name'] ?? data['fullName'] ?? '-').toString();
      final email = (data['email'] ?? '-').toString();
      final phone = (data['phone'] ?? data['phoneNumber'] ?? '-').toString();
      final emergencyPhone = (data['emergencyPhone'] ?? '-').toString();
      final personalAddress = (data['personalAddress'] ?? data['address'] ?? '-').toString();
      final bloodGroup = (data['bloodGroup'] ?? '-').toString();
      final specialization = (data['specialization'] ?? '-').toString();

      final rawTeamName = (data['teamName'] ?? data['team_name'] ?? '').toString();
      final teamId = (data['teamId'] ?? data['team_id'] ?? '-').toString();
      final officialAddress = (data['officialAddress'] ?? '-').toString();
      final role = (data['role'] ?? 'rescue_leader').toString();

      String joinedDateIso = '';
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        joinedDateIso = createdAt.toDate().toIso8601String();
      }

      // Resolve the team name (unchanged logic) before caching, so the
      // cache always holds the final display-ready name.
      final resolvedTeamName = await _resolveTeamName(rawTeamName, teamId);

      await RescueDao.cacheProfile(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        emergencyContact: emergencyPhone,
        personalAddress: personalAddress,
        specialization: specialization,
        bloodGroup: bloodGroup,
        teamName: resolvedTeamName,
        teamId: teamId,
        officialAddress: officialAddress,
        role: role,
        isLeader: role == 'rescue_leader' || role == 'team_leader',
        photoUrl: (data['photoUrl'] ?? '').toString(),
        createdAt: joinedDateIso,
      );

      final refreshed = await RescueDao.getCachedProfile(uid);
      if (mounted) {
        setState(() {
          _profile = refreshed;
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

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    return '$day ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        backgroundColor: kGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Personal Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('User not logged in'));
    }

    if (!_loadedOnce) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }

    if (_profile == null) {
      return const Center(child: Text('Profile data not found'));
    }

    final data = _profile!;
    final String name = data['name'] ?? '-';
    final String email = data['email'] ?? '-';
    final String phone = data['phone'] ?? '-';
    final String emergencyPhone = data['emergencyContact'] ?? '-';
    final String personalAddress = data['personalAddress'] ?? '-';
    final String bloodGroup = data['bloodGroup'] ?? '-';
    final String specialization = data['specialization'] ?? '-';
    final String teamName = data['teamName'] ?? '-';
    final String officialAddress = data['officialAddress'] ?? '-';
    final String teamId = data['teamId'] ?? '-';
    final String role = data['role'] ?? 'rescue_leader';
    final String roleLabel =
    (role == 'rescue_leader' || role == 'team_leader') ? 'Team Leader' : role;

    String joinedDate = '-';
    final createdAtStr = data['createdAt']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final dt = DateTime.tryParse(createdAtStr);
      if (dt != null) joinedDate = _formatDate(dt);
    }

    final bool profileIncomplete =
        name == '-' || phone == '-' || personalAddress == '-' || teamName == '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profileIncomplete)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Your profile is incomplete. Some details below are missing.',
                        style: TextStyle(fontSize: 12, color: Colors.black87)),
                  ),
                ],
              ),
            ),
          const Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFF2C3E50),
              child: Icon(Icons.person, size: 46, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 24),

          // ── SECTION 1: LEADER'S OWN DETAILS
          _sectionLabel('YOUR DETAILS'),
          const SizedBox(height: 10),
          _tile(Icons.badge_outlined, 'FULL NAME', name),
          const SizedBox(height: 10),
          _tile(Icons.email_outlined, 'EMAIL', email, trailing: Icons.lock_outline),
          const SizedBox(height: 10),
          _tile(Icons.phone_outlined, 'PHONE NUMBER', phone),
          const SizedBox(height: 10),
          _tile(Icons.emergency_outlined, 'EMERGENCY CONTACT', emergencyPhone),
          const SizedBox(height: 10),
          _tile(Icons.home_outlined, 'PERSONAL ADDRESS', personalAddress),
          const SizedBox(height: 10),
          // Specialization can be a long sentence, so it gets its own
          // full-width tile instead of being squeezed into half a row
          // (that squeeze was what made the box stretch vertically).
          _tile(Icons.star_outline, 'SPECIALIZATION', specialization,
              boldValue: true, maxLines: 3),
          const SizedBox(height: 10),
          _tile(Icons.bloodtype_outlined, 'BLOOD GROUP', bloodGroup,
              boldValue: true),

          const SizedBox(height: 26),

          // ── SECTION 2: TEAM'S DETAILS
          _sectionLabel('TEAM DETAILS'),
          const SizedBox(height: 10),
          _tile(Icons.group_outlined, 'TEAM NAME', teamName),
          const SizedBox(height: 10),
          _tile(Icons.business_outlined, 'OFFICIAL ADDRESS', officialAddress),
          const SizedBox(height: 10),
          // Team ID is a long random string, so it also gets its own
          // full-width tile instead of half a row.
          _tile(Icons.tag, 'TEAM ID', teamId, boldValue: true, maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _tile(Icons.calendar_today_outlined, 'JOINED DATE', joinedDate,
                    boldValue: true)),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(Icons.shield_outlined, 'ROLE', roleLabel,
                    boldValue: true)),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1.4));
  }

  Widget _tile(IconData icon, String label, String value,
      {IconData? trailing, bool boldValue = false, int maxLines = 2}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kLightBlue),
            child: Icon(icon, size: 20, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black45,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text(value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: boldValue ? FontWeight.bold : FontWeight.normal)),
            ]),
          ),
          if (trailing != null) Icon(trailing, size: 20, color: Colors.black38),
        ],
      ),
    );
  }
}