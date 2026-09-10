import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RescueNotificationPreferencesScreen extends StatefulWidget {
  const RescueNotificationPreferencesScreen({super.key});

  @override
  State<RescueNotificationPreferencesScreen> createState() =>
      _RescueNotificationPreferencesScreenState();
}

class _RescueNotificationPreferencesScreenState
    extends State<RescueNotificationPreferencesScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  bool _disasterAlerts = true;
  bool _taskAssignments = true;
  bool _isLoading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).get();
      final prefs = doc.data()?['notificationPrefs'] as Map<String, dynamic>?;
      if (prefs != null) {
        _disasterAlerts = prefs['disasterAlerts'] ?? true;
        _taskAssignments = prefs['taskAssignments'] ?? true;
      }
    } catch (_) {
      // Keep defaults (true) if the read fails
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Toggle par turant save — koi alag Save button nahi chahiye, switch UX ka standard tareeqa
  Future<void> _updatePref(String key, bool value) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(_uid).set({
        'notificationPrefs': {
          'disasterAlerts': key == 'disasterAlerts' ? value : _disasterAlerts,
          'taskAssignments': key == 'taskAssignments' ? value : _taskAssignments,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
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
        title: const Text('Notification Preferences',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _switchTile(
              title: 'Disaster Alerts',
              subtitle: 'Get notified about active disaster alerts in your area',
              value: _disasterAlerts,
              onChanged: (v) {
                setState(() => _disasterAlerts = v);
                _updatePref('disasterAlerts', v);
              },
            ),
            const SizedBox(height: 12),
            _switchTile(
              title: 'Task Assignments',
              subtitle: 'Get notified when you are assigned a rescue task',
              value: _taskAssignments,
              onChanged: (v) {
                setState(() => _taskAssignments = v);
                _updatePref('taskAssignments', v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        activeColor: kGreen,
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}