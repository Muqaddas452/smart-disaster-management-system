import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartdisaster/rescue_team_screens/view_task_screen.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize(BuildContext context) async {
    // Request permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Save FCM token to user document
    String? token = await _fcm.getToken();
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).update({
        'fcmToken': token,
      });
    }

    // Foreground Notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${message.notification!.title}: ${message.notification!.body}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                if (message.data.containsKey('taskId')) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ViewTaskScreen(taskId: message.data['taskId'])),
                  );
                }
              },
            ),
          ),
        );
      }
    });

    // Handle App launch from Notification Tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.containsKey('taskId')) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewTaskScreen(taskId: message.data['taskId'])),
        );
      }
    });
  }
}