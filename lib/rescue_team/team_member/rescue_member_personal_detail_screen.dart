import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RescueMemberPersonalDetailsScreen extends StatelessWidget {
  const RescueMemberPersonalDetailsScreen({super.key});

  static const Color kGreen = Color(0xFF1B5E38);
  static const Color kBgColor = Color(0xFFF7F7F2); // Soft light background matching leader screen

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: kBgColor,
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
      body: uid == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('rescueTeamUsers')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile data not found.'));
          }

          final data = snapshot.data!.data() ?? {};

          // Fetch Registration Data Fields
          final String name = data['name'] ?? data['fullName'] ?? 'N/A';
          final String email = data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? 'N/A';
          final String phone = data['phone'] ?? data['phoneNumber'] ?? 'N/A';
          final String emergencyPhone = data['emergencyPhone'] ?? 'N/A';
          final String specialization = data['specialization'] ?? 'Rescue Member';
          final String address = data['address'] ?? data['personalAddress'] ?? 'N/A';
          final String bloodGroup = data['bloodGroup'] ?? 'N/A';

          // Team Details
          final String rawTeamName = data['teamName'] ?? data['team_name'] ?? '';
          final String teamId = data['teamId'] ?? data['team_id'] ?? 'N/A';
          final String role = data['role'] ?? 'Rescue Member';

          // Dynamic Badge ID Handling
          final String badgeId = data['badgeId'] ?? '#RES-${uid.substring(0, 4).toUpperCase()}';

          // Date Formatting
          String joinedDateStr = 'N/A';
          if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
            final DateTime date = (data['createdAt'] as Timestamp).toDate();
            joinedDateStr = DateFormat('dd MMM yyyy').format(date);
          }

          return FutureBuilder<String>(
            future: _resolveTeamName(rawTeamName, teamId),
            builder: (context, teamNameSnapshot) {
              final String finalTeamName = teamNameSnapshot.data ?? (rawTeamName.isNotEmpty ? rawTeamName : '-');

              // Profile completion check
              final bool isIncomplete = name == 'N/A' || phone == 'N/A' || address == 'N/A' || finalTeamName == '-';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isIncomplete) _incompleteBanner(),
                    const SizedBox(height: 12),

                    // Avatar Section
                    const Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF2C3E50),
                        child: Icon(Icons.person, size: 60, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 1: YOUR DETAILS
                    const Text(
                      'YOUR DETAILS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _detailTile(Icons.badge_outlined, 'FULL NAME', name),
                    _detailTile(Icons.email_outlined, 'EMAIL', email, isLocked: true),
                    _detailTile(Icons.phone_outlined, 'PHONE NUMBER', phone),
                    _detailTile(Icons.contact_phone_outlined, 'EMERGENCY PHONE', emergencyPhone),
                    _detailTile(Icons.medical_services_outlined, 'SPECIALIZATION', specialization),
                    _detailTile(Icons.location_on_outlined, 'PERSONAL ADDRESS', address),
                    _detailTile(Icons.bloodtype_outlined, 'BLOOD GROUP', bloodGroup),

                    const SizedBox(height: 20),

                    // Section 2: TEAM DETAILS
                    const Text(
                      'TEAM DETAILS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _detailTile(Icons.group_outlined, 'TEAM NAME', finalTeamName),

                    Row(
                      children: [
                        Expanded(child: _detailTile(Icons.tag, 'BADGE ID', badgeId)),
                        const SizedBox(width: 12),
                        Expanded(child: _detailTile(Icons.calendar_today_outlined, 'JOINED DATE', joinedDateStr)),
                      ],
                    ),

                    _detailTile(Icons.security_outlined, 'ROLE', role),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Fallback solver to fetch team name directly from teams collection if missing
  Future<String> _resolveTeamName(String userDocTeamName, String teamId) async {
    if (userDocTeamName.trim().isNotEmpty && userDocTeamName != '-') {
      return userDocTeamName;
    }
    if (teamId.isEmpty || teamId == 'N/A') {
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

  Widget _incompleteBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your profile is incomplete. Some details below are missing.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value, {bool isLocked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withOpacity(0.08),
            ),
            child: Icon(icon, color: kGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isLocked)
            Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 18),
        ],
      ),
    );
  }
}