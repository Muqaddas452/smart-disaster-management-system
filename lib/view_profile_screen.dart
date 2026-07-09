import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'feedback_screen.dart';

// VIEW PROFILE SCREEN

class ViewProfileScreen extends StatelessWidget {
  const ViewProfileScreen({super.key});

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
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              } else if (value == 'notifications') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications tapped')),
                );
              } else if (value == 'feedback') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeedbackScreen(),
                  ),
                );
              } else if (value == 'signout') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: const Color(0xFF1B5E38)),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: Color(0xFF1B5E38),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Colors.black87),
                    const SizedBox(width: 12),
                    const Text('Notifications'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'feedback',
                child: Row(
                  children: [
                    const Icon(Icons.feedback, color: Colors.black87),
                    const SizedBox(width: 12),
                    const Text('Give Feedback'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // ---------- Profile Avatar ----------
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // ---------- Name ----------
            const Text(
              'Zain Ahmmed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 16),

            // ---------- Contact Information Section ----------
            _sectionTitle('CONTACT INFORMATION'),
            const SizedBox(height: 12),

            _contactCard(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'zain.ahmmed@example.com',
              trailingIcon: Icons.lock,
            ),
            const SizedBox(height: 10),
            _contactCard(
              icon: Icons.phone,
              title: 'Phone Number',
              subtitle: '+92 300 1234567',
            ),
            const SizedBox(height: 10),
            _contactCard(
              icon: Icons.location_on,
              title: 'Location',
              subtitle: 'Mandi Bahauddin, Pakistan',
            ),

            const SizedBox(height: 24),

            // ---------- Emergency Contact Section ----------
            _sectionTitle('EMERGENCY CONTACT'),
            const SizedBox(height: 12),

            _emergencyContactCard(context),
          ],
        ),
      ),
    );
  }

  // ---------------- Section Title ----------------
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

  // ---------------- Contact Card ----------------
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

  // ---------------- Emergency Contact Card ----------------
  Widget _emergencyContactCard(BuildContext context) {
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
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF5D020),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF7B5800),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ali Ahmmed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Relation: Brother',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
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
              const Expanded(
                child: Text(
                  '+92  301  9876543',
                  style: TextStyle(fontSize: 14, letterSpacing: 1),
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF1B5E38),
                child: const Icon(Icons.call, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}