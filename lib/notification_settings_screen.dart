import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isNotificationAllowed = true;

  // Custom Colors matching your app theme
  static const Color primaryDarkGreen = Color(0xFF1B5E38);
  static const Color scaffoldBg = Color(0xFFF5F5E8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: primaryDarkGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Top bar mein quick Switch Toggle
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Switch(
              value: _isNotificationAllowed,
              activeColor: Colors.white,
              activeTrackColor: Colors.green.shade700,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey,
              onChanged: (bool value) {
                setState(() {
                  _isNotificationAllowed = value;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isNotificationAllowed
                          ? 'Notifications Enabled'
                          : 'Notifications Blocked',
                    ),
                    backgroundColor:
                    _isNotificationAllowed ? primaryDarkGreen : Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
    const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
    child: Text(
    'Recent Notifications',
    style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.black54,
    ),
    ),
    ),
    const SizedBox(height: 8),

    // Live Notifications List from Firestore (Broadcasts / System Updates)
    Expanded(
    child: _isNotificationAllowed
    ? StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('Notifications')
        .where('user id', isEqualTo: FirebaseAuth.instance.currentUser?.uid) //filter for just login users
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots(),
    builder: (context, snapshot) {
    if (snapshot.hasError) {
    return Center(
    child: Text('Error: ${snapshot.error}'));
    }
    if (snapshot.connectionState ==
    ConnectionState.waiting) {
    return const Center(
    child: CircularProgressIndicator(
    color: primaryDarkGreen),
    );
    }

    final docs = snapshot.data!.docs;

    if (docs.isEmpty) {
    return Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(Icons.notifications_off_outlined,
    size: 48, color: Colors.grey.shade400),
    const SizedBox(height: 10),
    const Text(
    'No notifications yet.',
    style: TextStyle(
    fontSize: 15,
    color: Colors.grey,
    fontWeight: FontWeight.w500,
    ),
    ),
    ],
    ),
    );
    }

    return ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: docs.length,
    itemBuilder: (context, index) {
      final data =
      docs[index].data() as Map<String, dynamic>;
        //timestamp format
      Timestamp? timestamp = data['timestamp'];
      String timeString = '';
      if (timestamp != null) {
        DateTime dateTime = timestamp.toDate();
        timeString = DateFormat('MMM d, h:mm a').format(dateTime); // ex: Sep 6, 4:10 PM
      }
      String title = data['title'] ?? 'System Notification';
      String message =
          data['message'] ?? 'You have a new update.';

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.grey.shade300, width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications,
                color: primaryDarkGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),

                  Text(
                    timeString,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryDarkGreen.withOpacity(
                            0.1),
                        borderRadius:
                        BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
    },
    )
        : const Center(
    child: Text(
    'Notifications are blocked.',
    style: TextStyle(fontSize: 14, color: Colors.grey),
    ),
    ),
    ),
    ],
    ),
    );
    }
  }