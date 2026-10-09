import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';

class SystemSettingsCard extends StatefulWidget {
  const SystemSettingsCard({super.key});

  @override
  State<SystemSettingsCard> createState() => _SystemSettingsCardState();
}

class _SystemSettingsCardState extends State<SystemSettingsCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool maintenanceMode = false;
  bool autoRefresh = true;
  bool aiPrediction = true;
  bool dataSync = true;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final doc = await _firestore
        .collection("system_settings")
        .doc("dashboard")
        .get();

    if (doc.exists) {
      final data = doc.data()!;

      setState(() {
        maintenanceMode = data["maintenanceMode"] ?? false;
        autoRefresh = data["autoRefresh"] ?? true;
        aiPrediction = data["aiPrediction"] ?? true;
        dataSync = data["dataSync"] ?? true;
        loading = false;
      });
    } else {
      await _firestore
          .collection("system_settings")
          .doc("dashboard")
          .set({
        "maintenanceMode": false,
        "autoRefresh": true,
        "aiPrediction": true,
        "dataSync": true,
      });

      setState(() {
        maintenanceMode = false;
        autoRefresh = true;
        aiPrediction = true;
        dataSync = true;
        loading = false;
      });
    }
  }

  Future<void> saveSettings() async {
    await _firestore
        .collection("system_settings")
        .doc("dashboard")
        .set({
      "maintenanceMode": maintenanceMode,
      "autoRefresh": autoRefresh,
      "aiPrediction": aiPrediction,
      "dataSync": dataSync,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("System settings updated successfully"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings_system_daydream,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "System Settings",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _settingTile(
              title: "Maintenance Mode",
              subtitle:
              "Disable public access during system updates",
              icon: Icons.build_circle,
              value: maintenanceMode,
              onChanged: (value) async {
                setState(() {
                  maintenanceMode = value;
                });

                await saveSettings();
              },
            ),

            const Divider(),

            _settingTile(
              title: "Auto Refresh Data",
              subtitle:
              "Automatically update dashboard information",
              icon: Icons.refresh,
              value: autoRefresh,
              onChanged: (value) async {
                setState(() {
                  autoRefresh = value;
                });

                await saveSettings();
              },
            ),

            const Divider(),

            _settingTile(
              title: "AI Disaster Prediction",
              subtitle:
              "Enable AI model prediction services",
              icon: Icons.psychology,
              value: aiPrediction,
              onChanged: (value) async {
                setState(() {
                  aiPrediction = value;
                });

                await saveSettings();
              },
            ),

            const Divider(),

            _settingTile(
              title: "Real-Time Data Sync",
              subtitle:
              "Sync disaster data with Firebase",
              icon: Icons.cloud_sync,
              value: dataSync,
              onChanged: (value) async {
                setState(() {
                  dataSync = value;
                });

                await saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Icon(
          icon,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: Switch(
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}