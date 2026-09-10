import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';

// --- Screen Imports ---
import 'package:smart_disaster_management_system/citizen_screens/profile_completion_screen.dart';
import 'package:smart_disaster_management_system/splashscreen.dart';
import 'welcomescreen.dart';
import 'citizen_screens/signupscreen.dart';
import 'citizen_screens/login_screen.dart';
import 'citizen_screens/forgotpassword.dart';
import 'citizen_screens/citizen_home_screen.dart';
import 'citizen_screens/report_screen.dart';
import 'citizen_screens/safety_tips_screen.dart';
import 'citizen_screens/alert_screen.dart';
import 'citizen_screens/alert_details_screen.dart';
import 'citizen_screens/gps_access_screen.dart';
import 'rescue_team/rescue_home_screen.dart'; // Rescue Team Home Screen Import

// FCM topic configuration for specific district alerts
const String kUserDistrictTopic = "district_karachi";

// Top-level background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[FCM background] ${message.notification?.title}: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Request notification permissions for iOS and Android 13+
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Subscribe user to target district notification topic
  await FirebaseMessaging.instance.subscribeToTopic(kUserDistrictTopic);

  // Handle incoming messages while application is in foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('[FCM foreground] ${message.notification?.title}: ${message.notification?.body}');
  });

  // Handle notification tap events when application is launched from background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('[FCM tapped] district=${message.data['district']} disaster=${message.data['disaster']}');
  });

  runApp(const SmartDisasterApp());
}

class SmartDisasterApp extends StatelessWidget {
  const SmartDisasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Disaster Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      // Set AuthWrapper as initial landing entry point
      home: const AuthWrapper(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const SignUpScreen(),
        '/profileCompletion': (context) => const ProfileCompletionScreen(),
        '/citizenHome': (context) => const HomeScreen(),
      },
    );
  }
}

// ── MULTI-ROLE AUTHENTICATION WRAPPER ──
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Checks both authIndex and rescueTeamUsers to determine exact role
  Future<Map<String, dynamic>> _getUserRoleAndDetails(String uid) async {
    try {
      String role = '';
      String teamId = '';
      String teamName = 'Rescue Team';

      // 1. Fetch role from 'authIndex'
      final authIndexDoc = await FirebaseFirestore.instance
          .collection('authIndex')
          .doc(uid)
          .get();

      if (authIndexDoc.exists && authIndexDoc.data() != null) {
        role = (authIndexDoc.data()!['role'] ?? '').toString().trim().toLowerCase();
      }

      // 2. Fetch specific profile details from 'rescueTeamUsers'
      final rescueDoc = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .get();

      if (rescueDoc.exists && rescueDoc.data() != null) {
        final rescueData = rescueDoc.data()!;

        // Detailed role from rescueTeamUsers (e.g. 'rescue_leader', 'leader', 'member', etc.)
        final String detailedRole = (rescueData['role'] ?? '').toString().trim().toLowerCase();

        if (detailedRole.isNotEmpty) {
          role = detailedRole;
        }

        teamId = (rescueData['teamId'] ?? rescueData['team_id'] ?? '').toString();
        teamName = (rescueData['teamName'] ?? rescueData['team_name'] ?? 'Rescue Team').toString();
      }

      return {
        'role': role,
        'teamId': teamId,
        'teamName': teamName,
      };
    } catch (e) {
      print('Error checking role: $e');
      return {'role': 'citizen'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final String uid = snapshot.data!.uid;

          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserRoleAndDetails(uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
                  ),
                );
              }

              if (userSnapshot.hasData) {
                final userData = userSnapshot.data!;
                final String role = userData['role'] ?? 'citizen';
                final String teamId = userData['teamId'] ?? '';
                final String teamName = userData['teamName'] ?? 'Rescue Team';

                // Check Leader (Matches 'rescue_team', 'rescue_leader', 'leader', 'team_leader')
                final bool isLeader = role == 'rescue_team' ||
                    role.contains('leader') ||
                    role == 'rescue_leader' ||
                    role == 'team_leader';

                // Check Member
                final bool isMember = role.contains('member') ||
                    role == 'rescue_member' ||
                    role == 'team_member';

                if (isLeader) {
                  return RescueTeamHomeScreen(
                    isLeader: true,
                    teamId: teamId,
                    teamName: teamName,
                  );
                } else if (isMember) {
                  return RescueTeamHomeScreen(
                    isLeader: false,
                    teamId: teamId,
                    teamName: teamName,
                  );
                }
              }

              // Fallback to Citizen Home
              return const HomeScreen();
            },
          );
        }

        // FIXED: Replaced LoginScreen() with WelcomeScreen()
        return const WelcomeScreen();
      },
    );
  }
}