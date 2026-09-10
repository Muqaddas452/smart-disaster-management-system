import 'package:flutter/material.dart';
import 'editprofilescreen.dart';
import 'rescue_leader_notification_preferences_screen.dart';

class RescueSettingsScreen extends StatelessWidget {
  const RescueSettingsScreen({super.key});

  static const Color kGreen = Color(0xFF1B5E38);

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
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _tile(
              context,
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              subtitle: 'Update your name, contact & address',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notification Preferences',
              subtitle: 'Manage alert & task notifications',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RescueNotificationPreferencesScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: kGreen.withOpacity(0.08)),
              child: Icon(icon, color: kGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
}