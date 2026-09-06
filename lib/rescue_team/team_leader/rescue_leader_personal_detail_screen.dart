import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RescuePersonalDetailsScreen extends StatelessWidget {
  const RescuePersonalDetailsScreen({super.key});

  static const Color kGreen = Color(0xFF1B5E38);
  static const Color kLightBlue = Color(0xFFE8F4FD);

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

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
      body: uid == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
        FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kGreen));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile data not found'));
          }

          final data = snapshot.data!.data() ?? {};

          // ── Leader's own details
          final String name = data['name'] ?? '-';
          final String email = data['email'] ?? '-';
          final String phone = data['phone'] ?? '-';
          final String emergencyPhone = data['emergencyPhone'] ?? '-';
          final String personalAddress = data['personalAddress'] ?? '-';
          final String bloodGroup = data['bloodGroup'] ?? '-';
          final String specialization = data['specialization'] ?? '-';

          // ── Team's details
          final String teamName = data['teamName'] ?? '-';
          final String teamId = data['teamId'] ?? '-';
          final String officialAddress = data['officialAddress'] ?? '-';
          final String role = data['role'] ?? 'rescue_leader';
          final String roleLabel =
          (role == 'rescue_leader' || role == 'team_leader') ? 'Team Leader' : role;

          String joinedDate = '-';
          final createdAt = data['createdAt'];
          if (createdAt is Timestamp) {
            joinedDate = _formatDate(createdAt.toDate());
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
                Row(children: [
                  Expanded(
                      child: _tile(Icons.star_outline, 'SPECIALIZATION', specialization,
                          boldValue: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tile(Icons.bloodtype_outlined, 'BLOOD GROUP', bloodGroup,
                          boldValue: true)),
                ]),

                const SizedBox(height: 26),

                // ── SECTION 2: TEAM'S DETAILS (kept visually separate, same screen)
                _sectionLabel('TEAM DETAILS'),
                const SizedBox(height: 10),
                _tile(Icons.group_outlined, 'TEAM NAME', teamName),
                const SizedBox(height: 10),
                _tile(Icons.business_outlined, 'OFFICIAL ADDRESS', officialAddress),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _tile(Icons.tag, 'TEAM ID', teamId, boldValue: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tile(Icons.calendar_today_outlined, 'JOINED DATE', joinedDate,
                          boldValue: true)),
                ]),
                const SizedBox(height: 10),
                _tile(Icons.shield_outlined, 'ROLE', roleLabel, boldValue: true),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    return '$day ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1.4));
  }

  Widget _tile(IconData icon, String label, String value,
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