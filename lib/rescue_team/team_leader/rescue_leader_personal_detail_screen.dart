import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_disaster_management_system/database/rescue_dao.dart'; // adjust path if needed

// UI is exactly the same as before. The only addition: details are shown
// instantly from the SQLite cache (works offline too), then silently
// refreshed + re-cached whenever the live Firestore stream has new data.
class RescuePersonalDetailsScreen extends StatefulWidget {
  const RescuePersonalDetailsScreen({super.key});

  @override
  State<RescuePersonalDetailsScreen> createState() =>
      _RescuePersonalDetailsScreenState();
}

class _RescuePersonalDetailsScreenState
    extends State<RescuePersonalDetailsScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  Map<String, dynamic>? _profile;
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
      final data = snap.data() ?? {};

      final email = (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '-').toString();
      final phone = (data['phone'] ?? data['phoneNumber'] ?? '-').toString();
      final emergencyContact = (data['emergencyContact'] ?? '-').toString();
      final address = (data['address'] ?? data['personalAddress'] ?? '-').toString();
      final specialization = (data['specialization'] ?? '-').toString();
      final bloodGroup = (data['bloodGroup'] ?? '-').toString();
      final teamName = (data['teamName'] ?? '-').toString();
      final teamId = (data['teamId'] ?? '-').toString();
      final officialAddress = (data['officialAddress'] ?? '-').toString();
      final role = (data['role'] ?? 'rescue_leader').toString();
      final isLeader = data['isLeader'] == true || role == 'rescue_leader' || role == 'team_leader';
      final photoUrl = (data['photoUrl'] ?? '').toString();
      final createdAt = data['createdAt'];
      final createdAtStr = (createdAt is Timestamp) ? createdAt.toDate().toIso8601String() : '';

      await RescueDao.cacheProfile(
        uid: uid,
        name: (data['name'] ?? '').toString(),
        email: email,
        phone: phone,
        emergencyContact: emergencyContact,
        personalAddress: address,
        specialization: specialization,
        bloodGroup: bloodGroup,
        teamName: teamName,
        teamId: teamId,
        officialAddress: officialAddress,
        role: role,
        isLeader: isLeader,
        photoUrl: photoUrl,
        createdAt: createdAtStr,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        backgroundColor: kGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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

    final data = _profile ?? {};
    final String email = data['email'] ?? '-';
    final String phone = data['phone'] ?? '-';
    final String emergencyContact = data['emergencyContact'] ?? '-';
    final String address = data['personalAddress'] ?? '-';
    final String specialization = data['specialization'] ?? '-';
    final String bloodGroup = data['bloodGroup'] ?? '-';
    final String teamName = data['teamName'] ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PERSONAL DETAILS SECTION
          _buildDetailCard(
            icon: Icons.email_outlined,
            label: 'EMAIL',
            value: email,
            trailingIcon: Icons.lock_outline,
          ),
          _buildDetailCard(
            icon: Icons.phone_outlined,
            label: 'PHONE NUMBER',
            value: phone,
          ),
          _buildDetailCard(
            icon: Icons.medical_services_outlined,
            label: 'EMERGENCY CONTACT',
            value: emergencyContact,
          ),
          _buildDetailCard(
            icon: Icons.home_outlined,
            label: 'PERSONAL ADDRESS',
            value: address,
          ),
          _buildDetailCard(
            icon: Icons.star_outline,
            label: 'SPECIALIZATION',
            value: specialization,
          ),
          _buildDetailCard(
            icon: Icons.water_drop_outlined,
            label: 'BLOOD GROUP',
            value: bloodGroup,
          ),

          const SizedBox(height: 16),
          const Text(
            'TEAM DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black45,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // TEAM DETAILS SECTION
          _buildDetailCard(
            icon: Icons.group_outlined,
            label: 'TEAM NAME',
            value: teamName,
          ),
        ],
      ),
    );
  }

  // Card Widget with Flexible layout for long texts
  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    IconData? trailingIcon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withOpacity(0.08),
            ),
            child: Icon(icon, color: kGreen, size: 20),
          ),
          const SizedBox(width: 14),

          // Text Portion Wrapped in Expanded (Prevents character squeezing)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black45,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),

          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(trailingIcon, color: Colors.grey.shade400, size: 20),
          ],
        ],
      ),
    );
  }
}