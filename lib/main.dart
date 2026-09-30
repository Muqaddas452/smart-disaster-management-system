import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';
import 'package:sqflite/sqflite.dart';

// --- Screen Imports ---
import 'package:smartdisaster/citizen_screens/profile_completion_screen.dart';
import 'splashscreen.dart';
import 'welcomescreen.dart';
import 'citizen_screens/notification_settings_screen.dart';
import 'package:smartdisaster/citizen_screens/all_reports_screen.dart';
import 'role_selection_screen.dart';
import 'package:smartdisaster/citizen_screens/signupscreen.dart';
import 'package:smartdisaster/citizen_screens/login_screen.dart';
import 'package:smartdisaster/citizen_screens/forgotpassword.dart';
import 'package:smartdisaster/citizen_screens/citizen_home_screen.dart';
import 'package:smartdisaster/citizen_screens/report_screen.dart';
import 'package:smartdisaster/citizen_screens/safety_tips_screen.dart';
import 'package:smartdisaster/citizen_screens/alert_screen.dart';
import 'package:smartdisaster/citizen_screens/alert_details_screen.dart';
import 'package:smartdisaster/citizen_screens/gps_access_screen.dart';
import 'package:smartdisaster/rescue_team_screens/rescue_home_screen.dart'; // Rescue Team Home Screen Import
// NEW — needed so AuthWrapper can route pending/rejected rescue accounts
// to the same screen the login flow already uses, instead of letting
// them fall through to the dashboard on app reopen.
import 'package:smartdisaster/rescue_team_screens/pending_approval_screen.dart';

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

  // Register background message handler — this is just registering a
  // callback, no network call, so it's safe to keep here.
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // FIXED — runApp() now happens immediately after Firebase core init,
  // instead of waiting on network-dependent FCM setup first.
  //
  // WHY: `FirebaseMessaging.instance.subscribeToTopic(...)` sends an actual
  // network request to Firebase's servers. When there was no internet at
  // all, `await`-ing it here blocked runApp() from ever being called —
  // the app never rendered even its first frame, showing a permanently
  // blank white screen with no spinner (Flutter hadn't drawn anything
  // yet). Moving all FCM setup to run AFTER runApp(), without blocking
  // startup on it, fixes that while keeping the exact same behavior once
  // it succeeds.
  runApp(const SmartDisasterApp());

  // Fire-and-forget FCM setup — runs in the background after the UI is
  // already showing. Wrapped in try/catch so a failure (e.g. no internet)
  // is silently ignored instead of throwing an unhandled exception; the
  // person can just use the app normally and FCM setup will succeed
  // automatically next time there's a connection (permission +
  // subscribeToTopic are safe to call again).
  _setupFcm();
}

Future<void> _setupFcm() async {
  try {
    // Request notification permissions for iOS and Android 13+
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Subscribe user to target district notification topic
    await FirebaseMessaging.instance.subscribeToTopic(kUserDistrictTopic);
  } catch (e) {
    // Offline or FCM unavailable — safe to ignore, this just means push
    // notifications won't be set up until the next time there's internet.
    print('[FCM setup] skipped: $e');
  }

  // Handle incoming messages while application is in foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('[FCM foreground] ${message.notification?.title}: ${message.notification?.body}');
  });

  // Handle notification tap events when application is launched from background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('[FCM tapped] district=${message.data['district']} disaster=${message.data['disaster']}');
  });
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
  // AND approval status — this is what runs every time the app opens
  // while a session is still signed in.
  Future<Map<String, dynamic>> _getUserRoleAndDetails(String uid) async {
    try {
      String role = '';
      String teamId = '';
      String teamName = 'Rescue Team';
      // Citizens have no approval gate at all, so default to 'approved'
      // for them — this only matters once `role` turns out to be a
      // rescue leader/member below.
      String status = 'approved';

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

        // FIXED: this field was never being read before, so AuthWrapper
        // had no idea whether a rescue account was actually approved —
        // it only looked at `role`, which gets set at registration time
        // regardless of approval status. That let a pending/rejected
        // account reach the dashboard just by staying signed in and
        // reopening the app, even while the Login screen and Pending
        // Approval screen correctly still treated it as unapproved.
        status = (rescueData['status'] ?? 'pending').toString().trim().toLowerCase();
      }

      return {
        'role': role,
        'teamId': teamId,
        'teamName': teamName,
        'status': status,
      };
    } catch (e) {
      print('Error checking role: $e');
      return {'role': 'citizen', 'status': 'approved'};
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
                final String status = userData['status'] ?? 'approved';

                // Check Leader (Matches 'rescue_team', 'rescue_leader', 'leader', 'team_leader')
                final bool isLeader = role == 'rescue_team' ||
                    role.contains('leader') ||
                    role == 'rescue_leader' ||
                    role == 'team_leader';

                // Check Member
                final bool isMember = role.contains('member') ||
                    role == 'rescue_member' ||
                    role == 'team_member';

                if (isLeader || isMember) {
                  // FIXED: previously jumped straight to the dashboard
                  // based on role alone. Now it respects the same
                  // approval status the Login screen already enforces —
                  // a pending or rejected account is sent to
                  // PendingApprovalScreen instead, which keeps listening
                  // live and will move them on automatically once (and
                  // only once) an admin actually approves the team.
                  if (status == 'approved') {
                    return RescueTeamHomeScreen(
                      isLeader: isLeader,
                      teamId: teamId,
                      teamName: teamName,
                    );
                  } else {
                    return const PendingApprovalScreen();
                  }
                }
              }

              // Fallback to Citizen Home
              return const HomeScreen();
            },
          );
        }
        return const WelcomeScreen();
      },
    );
  }
}


















