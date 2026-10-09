import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends State<NotificationSettingsCard> {
  bool emailAlerts = true;
  bool smsAlerts = false;
  bool pushNotifications = true;
  bool emergencyBroadcastAlerts = true;

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection("admins")
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        final notificationData = data["notificationSettings"];

        if (notificationData is Map<String, dynamic>) {
          emailAlerts =
              notificationData["emailAlerts"] ?? true;

          smsAlerts =
              notificationData["smsAlerts"] ?? false;

          pushNotifications =
              notificationData["pushNotifications"] ?? true;

          emergencyBroadcastAlerts =
              notificationData["emergencyBroadcastAlerts"] ?? true;
        }
      }

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } catch (e) {
      debugPrint(
        "ERROR LOADING NOTIFICATION SETTINGS: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Unable to load notification settings.",
          ),
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (saving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "No admin account is currently signed in.",
          ),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection("admins")
          .doc(user.uid)
          .set(
        {
          "notificationSettings": {
            "emailAlerts": emailAlerts,
            "smsAlerts": smsAlerts,
            "pushNotifications": pushNotifications,
            "emergencyBroadcastAlerts":
            emergencyBroadcastAlerts,
          }
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "Notification settings saved successfully.",
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        "ERROR SAVING NOTIFICATION SETTINGS: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Unable to save notification settings.",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notification Settings",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "Manage how disaster alerts and system notifications are delivered.",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            SwitchListTile(
              secondary: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(
                  Icons.email_outlined,
                  color: Colors.blue,
                ),
              ),
              title: const Text(
                "Email Alerts",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                "Receive disaster notifications by email",
              ),
              value: emailAlerts,
              onChanged: (value) {
                setState(() {
                  emailAlerts = value;
                });
              },
            ),

            const Divider(),

            SwitchListTile(
              secondary: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(
                  Icons.sms_outlined,
                  color: Colors.green,
                ),
              ),
              title: const Text(
                "SMS Alerts",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                "Receive emergency alerts by SMS",
              ),
              value: smsAlerts,
              onChanged: (value) {
                setState(() {
                  smsAlerts = value;
                });
              },
            ),

            const Divider(),

            SwitchListTile(
              secondary: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.orange,
                ),
              ),
              title: const Text(
                "Push Notifications",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                "Receive alerts on your device",
              ),
              value: pushNotifications,
              onChanged: (value) {
                setState(() {
                  pushNotifications = value;
                });
              },
            ),

            const Divider(),

            SwitchListTile(
              secondary: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(
                  Icons.campaign_outlined,
                  color: Colors.red,
                ),
              ),
              title: const Text(
                "Emergency Broadcast Alerts",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                "Send high-priority disaster warnings",
              ),
              value: emergencyBroadcastAlerts,
              onChanged: (value) {
                setState(() {
                  emergencyBroadcastAlerts = value;
                });
              },
            ),

            const SizedBox(height: 15),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: saving ? null : _saveSettings,
                icon: saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(
                  saving ? "Saving..." : "Save Settings",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}