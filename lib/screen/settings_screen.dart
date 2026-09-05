import 'package:flutter/material.dart';

import '../widget/admin_profile_card.dart';
import '../widget/account_settings_card.dart';
import '../widget/notification_settings_card.dart';
import '../widget/system_settings_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            const Text(
              "Settings",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Manage your account, notifications and system preferences.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 25),

            // Admin Profile
            const AdminProfileCard(),

            const SizedBox(height: 20),

            // Account Settings
            const AccountSettingsCard(),

            const SizedBox(height: 20),

            // Notification Settings
            const NotificationSettingsCard(),

            const SizedBox(height: 20),

            // System Settings
            const SystemSettingsCard(),
          ],
        ),
      ),
    );
  }
}